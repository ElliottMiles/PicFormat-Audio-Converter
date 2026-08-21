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
        removeStaleConversionDirectories()

        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("Converted-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// Every conversion leaves a UUID-named folder behind with nothing to
    /// clean it up. As in the image app, only directories older than
    /// `staleConversionAge` are swept, as cheap insurance against
    /// deleting a batch the user might still be actively previewing or
    /// sharing. Bumped to 30 minutes (vs. the image app's 10) since
    /// listening through a batch of audio before saving realistically
    /// takes longer than glancing at a grid of photos.
    nonisolated private static let staleConversionAge: TimeInterval = 30 * 60

    nonisolated private static func removeStaleConversionDirectories() {
        let fileManager = FileManager.default
        let tempDir = fileManager.temporaryDirectory
        guard let contents = try? fileManager.contentsOfDirectory(
            at: tempDir,
            includingPropertiesForKeys: [.creationDateKey]
        ) else {
            return
        }

        let cutoff = Date().addingTimeInterval(-staleConversionAge)
        for url in contents where url.lastPathComponent.hasPrefix("Converted-") {
            guard let creationDate = try? url.resourceValues(forKeys: [.creationDateKey]).creationDate,
                  creationDate <= cutoff else {
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
