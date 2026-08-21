//
//  AudioConversionService.swift
//  Good_Audio_Converter
//
//  All actual audio encoding funnels through here. Reads decompressed
//  PCM from the source via AVAssetReader and re-encodes it to the target
//  format via AVAssetWriter, streaming sample buffers from one to the
//  other — the source is never fully decoded into memory at once, which
//  matters for multi-hundred-MB WAV imports the way it never did for the
//  image app's photos.
//

import AVFoundation
import CoreMedia

enum AudioConversionService {

    /// Converts the audio at `sourceURL` to `destinationURL`, streaming
    /// throughout. `metadata` is attached to the writer so title/artist/
    /// album/artwork survive the re-encode; see AudioMetadataService.
    nonisolated static func convert(
        sourceURL: URL,
        to format: AudioFormat,
        quality: AudioQuality,
        destinationURL: URL,
        metadata: [AVMetadataItem]
    ) async throws {
        guard FormatCapabilityService.isAvailable(format) else {
            throw ConversionError.formatUnavailable(format)
        }

        let sourceName = sourceURL.lastPathComponent
        let asset = AVURLAsset(url: sourceURL)

        guard let track = try await asset.loadTracks(withMediaType: .audio).first else {
            throw ConversionError.noAudioTrack(name: sourceName)
        }

        let (sampleRate, channels) = try await sourceFormat(of: track)

        let reader: AVAssetReader
        let writer: AVAssetWriter
        do {
            reader = try AVAssetReader(asset: asset)
            writer = try AVAssetWriter(outputURL: destinationURL, fileType: format.fileType)
        } catch {
            throw ConversionError.encodingFailed(name: sourceName, format: format, underlying: error)
        }

        let readerOutput = AVAssetReaderTrackOutput(track: track, outputSettings: [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVLinearPCMBitDepthKey: 32,
            AVLinearPCMIsFloatKey: true,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsNonInterleaved: false
        ])
        readerOutput.alwaysCopiesSampleData = false
        guard reader.canAdd(readerOutput) else {
            throw ConversionError.encodingFailed(name: sourceName, format: format, underlying: nil)
        }
        reader.add(readerOutput)

        let writerInput = AVAssetWriterInput(
            mediaType: .audio,
            outputSettings: format.encoderSettings(quality: quality, sampleRate: sampleRate, channels: channels)
        )
        writerInput.expectsMediaDataInRealTime = false
        guard writer.canAdd(writerInput) else {
            throw ConversionError.encodingFailed(name: sourceName, format: format, underlying: nil)
        }
        writer.add(writerInput)
        writer.metadata = metadata

        try? FileManager.default.removeItem(at: destinationURL)

        guard reader.startReading() else {
            throw ConversionError.encodingFailed(name: sourceName, format: format, underlying: reader.error)
        }
        guard writer.startWriting() else {
            throw ConversionError.encodingFailed(name: sourceName, format: format, underlying: writer.error)
        }
        writer.startSession(atSourceTime: .zero)

        try await pump(reader: reader, readerOutput: readerOutput, writer: writer, writerInput: writerInput)

        await writer.finishWriting()
        guard writer.status == .completed else {
            throw ConversionError.encodingFailed(name: sourceName, format: format, underlying: writer.error)
        }
    }

    /// Drains sample buffers from the reader into the writer input on a
    /// dedicated queue until the source is exhausted or something fails.
    /// `requestMediaDataWhenReady`'s handler is documented to stop firing
    /// once `markAsFinished()` is called, so each branch below resumes
    /// the continuation exactly once before returning.
    ///
    /// AVAssetReader/Writer and their inputs/outputs aren't marked
    /// `Sendable` in the SDK, but Apple's own documented usage of
    /// `requestMediaDataWhenReady` is exactly this — hand it a serial
    /// queue and drive the reader/writer from that queue's callback —
    /// so `Boxed` exists only to tell the compiler this specific,
    /// single-queue handoff is safe, not to bypass a real data race.
    nonisolated private static func pump(
        reader: AVAssetReader,
        readerOutput: AVAssetReaderTrackOutput,
        writer: AVAssetWriter,
        writerInput: AVAssetWriterInput
    ) async throws {
        let boxed = Boxed(reader: reader, readerOutput: readerOutput, writer: writer, writerInput: writerInput)

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let queue = DispatchQueue(label: "audio-conversion.pump")
            boxed.writerInput.requestMediaDataWhenReady(on: queue) {
                while boxed.writerInput.isReadyForMoreMediaData {
                    guard boxed.reader.status == .reading, let buffer = boxed.readerOutput.copyNextSampleBuffer() else {
                        boxed.writerInput.markAsFinished()
                        if boxed.reader.status == .failed {
                            boxed.reader.cancelReading()
                            continuation.resume(throwing: boxed.reader.error ?? CancellationError())
                        } else {
                            continuation.resume()
                        }
                        return
                    }

                    if !boxed.writerInput.append(buffer) {
                        boxed.writerInput.markAsFinished()
                        boxed.reader.cancelReading()
                        continuation.resume(throwing: boxed.writer.error ?? CancellationError())
                        return
                    }
                }
            }
        }
    }

    nonisolated private static func sourceFormat(of track: AVAssetTrack) async throws -> (sampleRate: Double, channels: Int) {
        let descriptions = try await track.load(.formatDescriptions)
        guard let description = descriptions.first,
              let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(description)?.pointee else {
            return (44_100, 2)
        }
        return (asbd.mSampleRate, Int(asbd.mChannelsPerFrame))
    }
}

private extension AudioFormat {
    nonisolated func encoderSettings(quality: AudioQuality, sampleRate: Double, channels: Int) -> [String: Any] {
        switch self {
        case .aac:
            return [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: sampleRate,
                AVNumberOfChannelsKey: channels,
                AVEncoderBitRateKey: quality.bitRate
            ]
        case .alac:
            return [
                AVFormatIDKey: kAudioFormatAppleLossless,
                AVSampleRateKey: sampleRate,
                AVNumberOfChannelsKey: channels,
                AVEncoderBitDepthHintKey: 16
            ]
        case .wav:
            return [
                AVFormatIDKey: kAudioFormatLinearPCM,
                AVSampleRateKey: sampleRate,
                AVNumberOfChannelsKey: channels,
                AVLinearPCMBitDepthKey: 16,
                AVLinearPCMIsFloatKey: false,
                AVLinearPCMIsBigEndianKey: false,
                AVLinearPCMIsNonInterleaved: false
            ]
        case .aiff:
            return [
                AVFormatIDKey: kAudioFormatLinearPCM,
                AVSampleRateKey: sampleRate,
                AVNumberOfChannelsKey: channels,
                AVLinearPCMBitDepthKey: 16,
                AVLinearPCMIsFloatKey: false,
                AVLinearPCMIsBigEndianKey: true,
                AVLinearPCMIsNonInterleaved: false
            ]
        }
    }
}

/// See the doc comment on `pump` — carries the reader/writer quartet
/// across the `@Sendable` closure boundary for the one queue that's
/// documented to own them for the duration of the pump.
nonisolated private struct Boxed: @unchecked Sendable {
    let reader: AVAssetReader
    let readerOutput: AVAssetReaderTrackOutput
    let writer: AVAssetWriter
    let writerInput: AVAssetWriterInput
}
