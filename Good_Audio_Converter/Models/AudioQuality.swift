//
//  AudioQuality.swift
//  Good_Audio_Converter
//

import Foundation

/// User-facing bitrate tiers. Only meaningful for formats where
/// `AudioFormat.supportsVariableQuality` is true; lossless formats
/// ignore the selected tier entirely, the same convention the sibling
/// image app uses for its own lossless formats.
enum AudioQuality: String, CaseIterable, Identifiable {
    case lossless
    case high
    case balanced
    case maximumCompression

    nonisolated var id: String { rawValue }

    nonisolated var displayName: String {
        switch self {
        case .lossless: return "Lossless"
        case .high: return "High Quality"
        case .balanced: return "Balanced"
        case .maximumCompression: return "Maximum Compression"
        }
    }

    nonisolated var subtitle: String {
        switch self {
        case .lossless: return "No quality loss, largest files"
        case .high: return "Minimal quality loss"
        case .balanced: return "Good tradeoff between size and quality"
        case .maximumCompression: return "Smallest files, more audible quality loss"
        }
    }

    /// Value passed to `AVEncoderBitRateKey` (bits per second) for the
    /// three AAC-producing tiers. AAC quality doesn't map to file size
    /// linearly any more than JPEG/HEIC quality does in the image app, so
    /// these are chosen the same way that app's `encoderQuality` values
    /// were: standard, widely-recognized bitrate points that step down in
    /// increasing jumps. 256 kbps is the bitrate Apple Music itself uses
    /// for AAC and is generally considered perceptually transparent.
    ///
    /// `.lossless`'s value here is unused dead weight, kept only so this
    /// switch stays exhaustive without introducing an optional: M4A
    /// routes `.lossless` to real ALAC encoding instead of reading this
    /// property at all — see AudioConversionService's `encoderSettings`.
    nonisolated var bitRate: Int {
        switch self {
        case .lossless: return 256_000
        case .high: return 192_000
        case .balanced: return 128_000
        case .maximumCompression: return 64_000
        }
    }

    nonisolated var systemImageName: String {
        switch self {
        case .lossless: return "checkmark.seal"
        case .high: return "star"
        case .balanced: return "scalemass"
        case .maximumCompression: return "arrow.down.circle"
        }
    }
}
