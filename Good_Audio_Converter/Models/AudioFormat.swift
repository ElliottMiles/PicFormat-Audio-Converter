//
//  AudioFormat.swift
//  Good_Audio_Converter
//
//  Output formats the app can produce. Availability is determined at
//  runtime by FormatCapabilityService — this enum only describes what a
//  format *is*, never whether the current device can actually encode it.
//
//  Deliberately does NOT include MP3 or FLAC: iOS/AudioToolbox has never
//  shipped a public encoder for either (decode-only), on every device,
//  not just some. That's a fixed platform fact rather than something
//  that varies by hardware/OS version, so — unlike HEIC in the sibling
//  image app — there's no "dimmed, unavailable" state worth building for
//  them. They're left out of this enum entirely rather than shipped as
//  an option that would never work for any real user.
//

import AudioToolbox
import AVFoundation
import UniformTypeIdentifiers

enum AudioFormat: String, CaseIterable, Identifiable, Hashable {
    case m4a
    case wav
    case aiff

    nonisolated var id: String { rawValue }

    /// The Core Audio format ID(s) this case can encode to. M4A spans two
    /// codecs behind one tile — AAC for the three lossy quality tiers,
    /// Apple Lossless (ALAC) for the Lossless tier — so both must be
    /// confirmed live-encodable, not just one, for the tile to be fully
    /// usable. See AudioConversionService's `encoderSettings` for which
    /// codec a given AudioQuality actually selects.
    nonisolated var requiredFormatIDs: [AudioFormatID] {
        switch self {
        case .m4a: return [kAudioFormatMPEG4AAC, kAudioFormatAppleLossless]
        case .wav, .aiff: return [kAudioFormatLinearPCM]
        }
    }

    /// The container AVAssetWriter should produce.
    nonisolated var fileType: AVFileType {
        switch self {
        case .m4a: return .m4a
        case .wav: return .wav
        case .aiff: return .aiff
        }
    }

    nonisolated var fileExtension: String {
        switch self {
        case .m4a: return "m4a"
        case .wav: return "wav"
        case .aiff: return "aiff"
        }
    }

    nonisolated var displayName: String {
        switch self {
        case .m4a: return "M4A"
        case .wav: return "WAV"
        case .aiff: return "AIFF"
        }
    }

    nonisolated var shortDescription: String {
        switch self {
        case .m4a: return "Lossless or compressed, your choice"
        case .wav: return "Lossless, uncompressed, universal"
        case .aiff: return "Lossless, uncompressed, Apple-friendly"
        }
    }

    /// Whether this format has a meaningful quality dial. M4A's dial
    /// spans a real codec switch (ALAC at the Lossless tier, AAC below
    /// it), not just a bitrate change within one codec — see
    /// AudioConversionService's `encoderSettings`.
    nonisolated var supportsVariableQuality: Bool {
        switch self {
        case .m4a: return true
        case .wav, .aiff: return false
        }
    }
}
