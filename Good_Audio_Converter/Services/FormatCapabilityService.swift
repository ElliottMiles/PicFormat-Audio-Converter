//
//  FormatCapabilityService.swift
//  Good_Audio_Converter
//
//  Determines, at runtime, which output formats this device can actually
//  encode. Same discipline as the sibling image app's version of this
//  file (which asks ImageIO what it can currently write instead of
//  hardcoding a format list): here we ask AudioToolbox what it can
//  currently encode to via kAudioFormatProperty_EncodeFormatIDs, the
//  audio-side equivalent of CGImageDestinationCopyTypeIdentifiers.
//
//  AAC, Apple Lossless, and Linear PCM are compiled directly into Core
//  Audio itself on both iOS and macOS — unlike AVIF/WebP in the image
//  app, which turned out to depend on optional ImageIO plugins that
//  exist on a developer's Mac but not on a real iPhone, these encoders
//  aren't a plugin bleeding through the Simulator's host process. So the
//  live check below is expected to report the same result in Simulator
//  and on a physical device, but it's still a live check rather than an
//  assumption, on the same principle.
//

import AudioToolbox

enum FormatCapabilityService {

    /// All formats this device can currently encode to, in the order
    /// they should be presented to the user.
    nonisolated static var availableFormats: [AudioFormat] {
        AudioFormat.allCases.filter(isAvailable)
    }

    nonisolated static func isAvailable(_ format: AudioFormat) -> Bool {
        format.requiredFormatIDs.allSatisfy { encodableFormatIDs.contains($0) }
    }

    /// AudioToolbox's live list of format IDs it can currently encode.
    nonisolated private static let encodableFormatIDs: Set<AudioFormatID> = {
        var propertySize: UInt32 = 0
        let sizeStatus = AudioFormatGetPropertyInfo(
            kAudioFormatProperty_EncodeFormatIDs, 0, nil, &propertySize
        )
        guard sizeStatus == noErr, propertySize > 0 else { return [] }

        let count = Int(propertySize) / MemoryLayout<AudioFormatID>.size
        var formatIDs = [AudioFormatID](repeating: 0, count: count)
        let status = AudioFormatGetProperty(
            kAudioFormatProperty_EncodeFormatIDs, 0, nil, &propertySize, &formatIDs
        )
        guard status == noErr else { return [] }

        return Set(formatIDs)
    }()
}
