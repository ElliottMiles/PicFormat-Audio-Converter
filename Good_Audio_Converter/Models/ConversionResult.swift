//
//  ConversionResult.swift
//  Good_Audio_Converter
//
//  Points at a file AudioConversionService already streamed to disk —
//  unlike the image app's ConversionResult, there's no in-memory Data
//  here to keep the memory-architecture discipline consistent end to
//  end. Save/Share hand this URL straight to the system pickers with no
//  extra copy step.
//

import Foundation

struct ConversionResult: Identifiable {
    let id = UUID()
    let sourceID: UUID
    let filename: String
    let fileURL: URL
    let format: AudioFormat
    let byteCount: Int
    let duration: TimeInterval

    var formattedByteCount: String {
        ByteCountFormatter.string(fromByteCount: Int64(byteCount), countStyle: .file)
    }

    var formattedDuration: String { duration.formattedDuration }
}

enum ConversionError: LocalizedError {
    case encodingFailed(name: String, format: AudioFormat, underlying: Error?)
    case formatUnavailable(AudioFormat)
    case noAudioTrack(name: String)

    var errorDescription: String? {
        switch self {
        case .encodingFailed(let name, let format, let underlying):
            let base = "\"\(name)\" couldn't be converted to \(format.displayName)."
            guard let underlying else { return base }
            return base + " (\(underlying.localizedDescription))"
        case .formatUnavailable(let format):
            return "\(format.displayName) isn't available on this device."
        case .noAudioTrack(let name):
            return "\"\(name)\" doesn't contain any audio."
        }
    }
}
