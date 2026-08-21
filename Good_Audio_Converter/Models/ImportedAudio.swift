//
//  ImportedAudio.swift
//  Good_Audio_Converter
//
//  A source audio file pulled in from Files or the microphone, ready to
//  feed into the conversion pipeline.
//
//  Deliberately holds a file URL, not decoded audio. Unlike the image
//  app's ImportedImage (which keeps a full decoded CGImage in memory —
//  fine for photos), a handful of uncompressed WAVs can be hundreds of
//  MB each, so this app never fully materializes audio in memory: import
//  keeps a reference to an on-disk copy, and conversion streams
//  URL-to-URL.
//

import Foundation

struct ImportedAudio: Identifiable, Equatable {
    let id = UUID()
    /// On-disk location of the source file (a Files-import "Inbox" copy,
    /// or a recording written directly by AVAudioRecorder).
    let sourceURL: URL
    /// Name to base the output filename on (without extension).
    let baseFilename: String
    let duration: TimeInterval
    let fileSize: Int
    let title: String?
    let artist: String?

    static func == (lhs: ImportedAudio, rhs: ImportedAudio) -> Bool {
        lhs.id == rhs.id
    }

    var formattedDuration: String { duration.formattedDuration }

    var formattedFileSize: String {
        ByteCountFormatter.string(fromByteCount: Int64(fileSize), countStyle: .file)
    }

    /// What to show as a subtitle in the import list: prefer real
    /// metadata (artist) when we have it, otherwise fall back to
    /// duration/size, which every file has.
    var subtitle: String {
        if let artist, !artist.isEmpty {
            return "\(artist) · \(formattedDuration)"
        }
        return "\(formattedDuration) · \(formattedFileSize)"
    }
}

enum ImportError: LocalizedError {
    case unreadableFile(name: String)
    case noAudioTrack(name: String)
    case microphonePermissionDenied
    case batchLimitReached

    var errorDescription: String? {
        switch self {
        case .unreadableFile(let name):
            return "\"\(name)\" couldn't be read as an audio file."
        case .noAudioTrack(let name):
            return "\"\(name)\" doesn't contain any audio."
        case .microphonePermissionDenied:
            return "Microphone access was denied. Enable it in Settings to record audio."
        case .batchLimitReached:
            return "That batch limit has been reached for this session."
        }
    }
}
