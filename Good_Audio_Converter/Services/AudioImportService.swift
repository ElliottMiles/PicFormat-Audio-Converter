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
