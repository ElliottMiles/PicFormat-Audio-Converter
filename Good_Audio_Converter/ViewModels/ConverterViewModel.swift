//
//  ConverterViewModel.swift
//  Good_Audio_Converter
//
//  Owns the whole import -> configure -> convert -> export flow.
//

import AVFoundation
import Foundation
import Observation

@Observable
@MainActor
final class ConverterViewModel {

    /// Batch caps are duration/size-based rather than a flat item count
    /// like the image app's 25-image cap: a handful of uncompressed WAVs
    /// can be hundreds of MB each, so "how many files" isn't the
    /// meaningful constraint the way it is for photos. Three hours is
    /// generous for legitimate batches (a podcast season, an audiobook's
    /// chapters) while still bounding worst-case temp-disk usage and
    /// conversion time. `maxItems` is a secondary, generous sanity cap
    /// purely so the import list itself doesn't become unwieldy — it's
    /// not the primary constraint.
    static let maxTotalDuration: TimeInterval = 3 * 60 * 60
    static let maxItems = 50

    // Import
    private(set) var importedAudio: [ImportedAudio] = []
    var importIssues: [String] = []

    // Configuration
    let availableFormats: [AudioFormat] = FormatCapabilityService.availableFormats
    var selectedFormat: AudioFormat?
    var selectedQuality: AudioQuality = .high
    var outputBaseName: String = "Converted"

    // Conversion
    private(set) var conversionResults: [ConversionResult] = []
    var conversionIssues: [String] = []
    var isConverting = false

    // Export
    var isPresentingSaveSheet = false
    var isPresentingShareSheet = false
    var saveConfirmationMessage: String?

    // Preview playback (Results screen)
    let previewPlayer = AudioPreviewPlayer()

    init() {
        selectedFormat = availableFormats.first(where: { $0 == .aac }) ?? availableFormats.first
    }

    var hasAudio: Bool { !importedAudio.isEmpty }
    var hasResults: Bool { !conversionResults.isEmpty }
    var isBatch: Bool { importedAudio.count > 1 }

    var totalDuration: TimeInterval {
        importedAudio.reduce(0) { $0 + $1.duration }
    }

    var remainingDurationCapacity: TimeInterval {
        max(0, Self.maxTotalDuration - totalDuration)
    }

    var totalOriginalBytes: Int {
        importedAudio.reduce(0) { $0 + $1.fileSize }
    }

    var totalConvertedBytes: Int {
        conversionResults.reduce(0) { $0 + $1.byteCount }
    }

    /// URLs already sitting on disk from conversion — no separate
    /// "prepare files for export" step needed, unlike the image app,
    /// since AudioConversionService streams straight to these locations.
    var exportURLs: [URL] {
        conversionResults.map(\.fileURL)
    }

    // MARK: - Import

    func addAudio(_ item: ImportedAudio) {
        guard importedAudio.count < Self.maxItems else {
            importIssues.append("Skipped \"\(item.baseFilename)\" — reached the \(Self.maxItems)-file batch limit.")
            return
        }
        guard item.duration <= remainingDurationCapacity else {
            let hours = Int(Self.maxTotalDuration / 3600)
            importIssues.append("Skipped \"\(item.baseFilename)\" — batch duration limit (\(hours) hours total) reached.")
            return
        }
        importedAudio.append(item)
        syncOutputBaseNameIfNeeded()
    }

    func addAudio(result: Result<ImportedAudio, Error>) {
        switch result {
        case .success(let item):
            addAudio(item)
        case .failure(let error):
            importIssues.append(error.localizedDescription)
        }
    }

    func addAudioItems(_ results: [Result<ImportedAudio, Error>]) {
        for result in results {
            addAudio(result: result)
        }
    }

    func removeAudio(_ item: ImportedAudio) {
        importedAudio.removeAll { $0.id == item.id }
        if importedAudio.isEmpty {
            outputBaseName = "Converted"
        }
    }

    private func syncOutputBaseNameIfNeeded() {
        guard importedAudio.count == 1, outputBaseName == "Converted" else { return }
        outputBaseName = importedAudio[0].baseFilename
    }

    // MARK: - Conversion

    func convert() async {
        guard let format = selectedFormat, hasAudio else { return }

        previewPlayer.stop()
        isConverting = true
        conversionIssues.removeAll()
        conversionResults.removeAll()

        let items = importedAudio
        let quality = selectedQuality
        let baseName = outputBaseName

        // Task.detached specifically, not a plain Task{} — with
        // SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor, a plain Task created
        // from this MainActor method would still run on the main actor by
        // inheritance, which would silently defeat the point of this.
        let (results, issues) = await Task.detached(priority: .userInitiated) {
            await Self.convertSequentially(items: items, baseName: baseName, format: format, quality: quality)
        }.value

        conversionResults = results
        conversionIssues = issues
        isConverting = false
    }

    nonisolated private static func convertSequentially(
        items: [ImportedAudio],
        baseName: String,
        format: AudioFormat,
        quality: AudioQuality
    ) async -> (results: [ConversionResult], issues: [String]) {
        var results: [ConversionResult] = []
        var issues: [String] = []

        let destinationDir: URL
        do {
            destinationDir = try FileExportService.makeConversionDirectory()
        } catch {
            issues.append("Couldn't prepare a location to save converted files: \(error.localizedDescription)")
            return (results, issues)
        }

        let filenames = FileExportService.filenames(baseName: baseName, count: items.count, extension: format.fileExtension)

        for (item, filename) in zip(items, filenames) {
            let destinationURL = destinationDir.appendingPathComponent(filename)
            do {
                let metadata = await AudioMetadataService.loadTransferableMetadata(from: AVURLAsset(url: item.sourceURL))
                try await AudioConversionService.convert(
                    sourceURL: item.sourceURL,
                    to: format,
                    quality: quality,
                    destinationURL: destinationURL,
                    metadata: metadata
                )

                let attributes = try? FileManager.default.attributesOfItem(atPath: destinationURL.path)
                let byteCount = (attributes?[.size] as? Int) ?? 0
                let outputDuration = try? await AVURLAsset(url: destinationURL).load(.duration)
                let seconds = outputDuration.map(CMTimeGetSeconds) ?? item.duration

                results.append(ConversionResult(
                    sourceID: item.id,
                    filename: filename,
                    fileURL: destinationURL,
                    format: format,
                    byteCount: byteCount,
                    duration: seconds
                ))
            } catch {
                issues.append(error.localizedDescription)
            }
        }

        return (results, issues)
    }

    // MARK: - Export

    func handleSaveCompletion(success: Bool) {
        guard success else { return }
        saveConfirmationMessage = conversionResults.count == 1
            ? "Saved \(conversionResults[0].filename)."
            : "Saved \(conversionResults.count) files."
    }

    /// Called when the user leaves the results screen — a much more
    /// reliable "done with this batch" signal than any time-based sweep,
    /// since it doesn't depend on the app ever being reopened. Doesn't
    /// wait on Save/Share specifically, so doing both (or neither) from
    /// the same visit still works: the files stay put until the whole
    /// screen goes away.
    func cleanUpConversionResults() {
        guard let directory = conversionResults.first?.fileURL.deletingLastPathComponent() else { return }
        conversionResults.removeAll()
        Task.detached(priority: .utility) {
            FileExportService.removeDirectory(at: directory)
        }
    }
}
