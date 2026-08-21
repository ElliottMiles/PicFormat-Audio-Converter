//
//  AudioMetadataService.swift
//  Good_Audio_Converter
//
//  AVFoundation doesn't carry ID3/iTunes-style metadata across a
//  re-encode automatically the way it bakes in orientation for images —
//  a converted file loses its title/artist/album/artwork unless we
//  explicitly copy them over. AVAsset's `commonMetadata` already
//  normalizes ID3 (mp3), iTunes (m4a), and other format-specific tags
//  onto a shared set of common keys, so reading from there (rather than
//  each format's native keyspace) is what lets a single code path carry
//  metadata from any supported source into any supported destination.
//

import AVFoundation

enum AudioMetadataService {

    /// The common-key metadata items worth carrying over: the ones the
    /// app's own import list and the task both call out (title, artist,
    /// album, artwork). Common metadata items load synchronously once
    /// fetched via `asset.load(.commonMetadata)` — only the asset-level
    /// property itself needs `await`.
    nonisolated static func loadTransferableMetadata(from asset: AVAsset) async -> [AVMetadataItem] {
        guard let commonMetadata = try? await asset.load(.commonMetadata) else { return [] }

        let identifiers: [AVMetadataIdentifier] = [
            .commonIdentifierTitle,
            .commonIdentifierArtist,
            .commonIdentifierAlbumName,
            .commonIdentifierArtwork
        ]

        return identifiers.compactMap { identifier in
            guard let match = AVMetadataItem.metadataItems(from: commonMetadata, filteredByIdentifier: identifier).first,
                  let copy = match.mutableCopy() as? AVMutableMetadataItem else {
                return nil
            }
            return copy
        }
    }

    /// Convenience for the import list: just the title/artist strings,
    /// used to give imported rows a nicer subtitle than the raw
    /// filename when real metadata is present.
    nonisolated static func loadTitleAndArtist(from asset: AVAsset) async -> (title: String?, artist: String?) {
        guard let commonMetadata = try? await asset.load(.commonMetadata) else { return (nil, nil) }

        let title = await stringValue(for: .commonIdentifierTitle, in: commonMetadata)
        let artist = await stringValue(for: .commonIdentifierArtist, in: commonMetadata)
        return (title, artist)
    }

    nonisolated private static func stringValue(for identifier: AVMetadataIdentifier, in items: [AVMetadataItem]) async -> String? {
        guard let item = AVMetadataItem.metadataItems(from: items, filteredByIdentifier: identifier).first else {
            return nil
        }
        return try? await item.load(.stringValue)
    }
}
