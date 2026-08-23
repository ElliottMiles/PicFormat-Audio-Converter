//
//  FileExportService.swift
//  Good_Audio_Converter
//

import Foundation

enum FileExportService {

    /// Creates a fresh scratch directory for one conversion batch to
    /// stream its output files into. AudioConversionService writes
    /// directly into this directory, so — unlike the image app, which
    /// builds Data in memory and only writes temporary files when the
    /// user taps Save/Share — the files are already at their final
    /// on-disk location by the time results are shown, ready to hand to
    /// UIDocumentPickerViewController/UIActivityViewController or play
    /// back with no extra copy step.
    nonisolated static func makeConversionDirectory() throws -> URL {
        performStaleCleanup()

        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("Converted-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// Sweeps every scratch location the app writes to — converted
    /// output, imported source copies, and raw recordings — of anything
    /// old enough the user is unlikely to still be using it. Safe to
    /// call opportunistically: before a new conversion (as before), and
    /// now once at app launch too, so a single-session user still gets
    /// swept on their next open rather than only on a second conversion.
    nonisolated static func performStaleCleanup() {
        removeStaleConversionDirectories()
        removeStaleImports()
        removeStaleRecordings()
    }

    /// Every conversion leaves a UUID-named folder behind with nothing to
    /// clean it up. As in the image app, only directories older than
    /// `staleAge` are swept, as cheap insurance against deleting a batch
    /// the user might still be actively previewing or sharing. Bumped to
    /// 30 minutes (vs. the image app's 10) since listening through a
    /// batch of audio before saving realistically takes longer than
    /// glancing at a grid of photos.
    nonisolated private static let staleAge: TimeInterval = 30 * 60

    nonisolated private static func removeStaleConversionDirectories() {
        let fileManager = FileManager.default
        let tempDir = fileManager.temporaryDirectory
        guard let contents = try? fileManager.contentsOfDirectory(
            at: tempDir,
            includingPropertiesForKeys: [.creationDateKey]
        ) else {
            return
        }

        let cutoff = Date().addingTimeInterval(-staleAge)
        for url in contents where url.lastPathComponent.hasPrefix("Converted-") {
            guard let creationDate = try? url.resourceValues(forKeys: [.creationDateKey]).creationDate,
                  creationDate <= cutoff else {
                continue
            }
            try? fileManager.removeItem(at: url)
        }
    }

    /// Files-picker imports get copied into this app-owned directory
    /// (see AudioImportService.importPickedFile) instead of being left
    /// at whatever undocumented tmp location UIDocumentPickerViewController's
    /// `asCopy: true` used, specifically so they can be swept here.
    nonisolated private static func removeStaleImports() {
        let importsDir = FileManager.default.temporaryDirectory.appendingPathComponent("Imports", isDirectory: true)
        removeStaleContents(of: importsDir, olderThan: Date().addingTimeInterval(-staleAge), dateKeyPath: \.creationDate)
    }

    /// Recordings are written to continuously while in progress, so
    /// modification date — not creation date — is what keeps an
    /// actively-recording file from looking stale mid-recording.
    nonisolated private static func removeStaleRecordings() {
        let recordingsDir = FileManager.default.temporaryDirectory.appendingPathComponent("Recordings", isDirectory: true)
        removeStaleContents(of: recordingsDir, olderThan: Date().addingTimeInterval(-staleAge), dateKeyPath: \.contentModificationDate)
    }

    nonisolated private static func removeStaleContents(of directory: URL, olderThan cutoff: Date, dateKeyPath: KeyPath<URLResourceValues, Date?>) {
        let fileManager = FileManager.default
        guard let contents = try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.creationDateKey, .contentModificationDateKey]
        ) else {
            return
        }

        for url in contents {
            guard let values = try? url.resourceValues(forKeys: [.creationDateKey, .contentModificationDateKey]),
                  let date = values[keyPath: dateKeyPath],
                  date <= cutoff else {
                continue
            }
            try? fileManager.removeItem(at: url)
        }
    }

    /// Builds final on-disk filenames for a batch, keeping filenames
    /// stable and collision-free even if the user's base name repeats
    /// across a batch import.
    nonisolated static func filenames(baseName: String, count: Int, extension ext: String) -> [String] {
        let sanitized = sanitize(baseName)
        if count == 1 {
            return ["\(sanitized).\(ext)"]
        }
        return (1...count).map { "\(sanitized)-\($0).\(ext)" }
    }

    nonisolated static func sanitize(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let invalidCharacters = CharacterSet(charactersIn: "/\\:*?\"<>|")
        let cleaned = trimmed.components(separatedBy: invalidCharacters).joined(separator: "-")
        return cleaned.isEmpty ? "Converted Audio" : cleaned
    }
}
