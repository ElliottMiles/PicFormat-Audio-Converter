//
//  AudioImportService.swift
//  Good_Audio_Converter
//
//  Turns a file URL (from Files or a fresh microphone recording) into an
//  ImportedAudio: reads duration, file size, and any title/artist tags
//  without decoding the audio itself.
//

import AVFoundation

enum AudioImportService {

    /// Copies a Files-picker URL into an app-owned `Imports/` directory
    /// before reading it, rather than trusting whatever undocumented tmp
    /// location UIDocumentPickerViewController's `asCopy: true` used —
    /// this is a location FileExportService's stale-sweep actually knows
    /// about.
    nonisolated static func importPickedFile(from pickedURL: URL) async throws -> ImportedAudio {
        let copiedURL = try copyIntoImports(pickedURL)
        return try await importFile(url: copiedURL)
    }

    nonisolated private static func copyIntoImports(_ sourceURL: URL) throws -> URL {
        let importDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("Imports", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: importDir, withIntermediateDirectories: true)

        let destination = importDir.appendingPathComponent(sourceURL.lastPathComponent)
        try FileManager.default.copyItem(at: sourceURL, to: destination)
        return destination
    }

    nonisolated static func importFile(url: URL, suggestedName: String? = nil) async throws -> ImportedAudio {
        let displayName = suggestedName ?? url.lastPathComponent
        let asset = AVURLAsset(url: url)

        guard try await asset.loadTracks(withMediaType: .audio).first != nil else {
            throw ImportError.noAudioTrack(name: displayName)
        }

        let duration = try await asset.load(.duration)
        let seconds = duration.isNumeric ? CMTimeGetSeconds(duration) : 0

        let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
        let fileSize = (attributes?[.size] as? Int) ?? 0
        let (title, artist) = await AudioMetadataService.loadTitleAndArtist(from: asset)

        return ImportedAudio(
            sourceURL: url,
            baseFilename: baseFilename(from: displayName),
            duration: seconds,
            fileSize: fileSize,
            title: title,
            artist: artist
        )
    }

    nonisolated private static func baseFilename(from name: String) -> String {
        let stripped = (name as NSString).deletingPathExtension
        return stripped.isEmpty ? "Audio" : stripped
    }
}
