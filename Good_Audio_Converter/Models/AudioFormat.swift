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
    case aac
    case alac
    case wav
    case aiff

    nonisolated var id: String { rawValue }

    /// The Core Audio format ID this case encodes to, used both to drive
    /// AVAssetWriter's output settings and to check live encoder
    /// availability via FormatCapabilityService.
    nonisolated var formatID: AudioFormatID {
        switch self {
        case .aac: return kAudioFormatMPEG4AAC
        case .alac: return kAudioFormatAppleLossless
        case .wav, .aiff: return kAudioFormatLinearPCM
        }
    }

    /// The container AVAssetWriter should produce.
    nonisolated var fileType: AVFileType {
        switch self {
        case .aac, .alac: return .m4a
        case .wav: return .wav
        case .aiff: return .aiff
        }
    }

    nonisolated var fileExtension: String {
        switch self {
        case .aac, .alac: return "m4a"
        case .wav: return "wav"
        case .aiff: return "aiff"
        }
    }

    nonisolated var displayName: String {
        switch self {
        case .aac: return "AAC"
        case .alac: return "Apple Lossless"
        case .wav: return "WAV"
        case .aiff: return "AIFF"
        }
    }

    nonisolated var shortDescription: String {
        switch self {
        case .aac: return "Universal, adjustable compression"
        case .alac: return "Lossless, smaller than WAV/AIFF"
        case .wav: return "Lossless, uncompressed, universal"
        case .aiff: return "Lossless, uncompressed, Apple-friendly"
        }
    }

    /// Whether this format has a meaningful lossy/bitrate dial. ALAC is
    /// lossless-but-compressed, so — like PNG in the image app — it
    /// always encodes at full fidelity regardless of the selected tier.
    nonisolated var supportsVariableQuality: Bool {
        switch self {
        case .aac: return true
        case .alac, .wav, .aiff: return false
        }
    }
}
