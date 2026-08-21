//
//  Good_Audio_ConverterTests.swift
//  Good_Audio_ConverterTests
//

import Testing
import Foundation
import AVFoundation
@testable import Good_Audio_Converter

// MARK: - FileExportService

@Suite("FileExportService.sanitize")
struct FileExportServiceSanitizeTests {

    @Test(arguments: ["/", "\\", ":", "*", "?", "\"", "<", ">", "|"])
    func replacesEachForbiddenCharacterWithDash(character: String) {
        let name = "a\(character)b"
        #expect(FileExportService.sanitize(name) == "a-b")
    }

    @Test func emptyInputFallsBackToDefaultName() {
        #expect(FileExportService.sanitize("") == "Converted Audio")
    }

    @Test func whitespaceOnlyInputFallsBackToDefaultName() {
        #expect(FileExportService.sanitize("   ") == "Converted Audio")
    }

    @Test func alreadyCleanNameIsUnchanged() {
        #expect(FileExportService.sanitize("My Podcast 2024") == "My Podcast 2024")
    }

    @Test func trimsSurroundingWhitespace() {
        #expect(FileExportService.sanitize("  episode  ") == "episode")
    }
}

@Suite("FileExportService.filenames")
struct FileExportServiceFilenamesTests {

    @Test func singleFileHasNoNumericSuffix() {
        let names = FileExportService.filenames(baseName: "episode", count: 1, extension: "m4a")
        #expect(names == ["episode.m4a"])
    }

    @Test func multiFileNumbersSequentiallyFromOne() {
        let names = FileExportService.filenames(baseName: "episode", count: 3, extension: "wav")
        #expect(names == ["episode-1.wav", "episode-2.wav", "episode-3.wav"])
    }

    @Test func singleFileSanitizesBaseName() {
        let names = FileExportService.filenames(baseName: "my/trip", count: 1, extension: "m4a")
        #expect(names == ["my-trip.m4a"])
    }

    @Test func multiFileSanitizesBaseName() {
        let names = FileExportService.filenames(baseName: "my:trip", count: 2, extension: "wav")
        #expect(names == ["my-trip-1.wav", "my-trip-2.wav"])
    }
}

// MARK: - FormatCapabilityService

@Suite("FormatCapabilityService")
struct FormatCapabilityServiceTests {

    // AAC, Apple Lossless, and Linear PCM are compiled into Core Audio
    // itself on every iOS device and the Simulator alike (see the
    // doc comment on FormatCapabilityService for why that's different
    // from the image app's AVIF/WebP situation), so this is expected to
    // hold everywhere, not just in this environment.
    @Test func allFourCandidateFormatsAreEncodable() {
        for format in AudioFormat.allCases {
            #expect(FormatCapabilityService.isAvailable(format), "\(format.displayName) should be encodable")
        }
    }

    @Test func availableFormatsMatchesAllCasesHere() {
        #expect(FormatCapabilityService.availableFormats.count == AudioFormat.allCases.count)
    }
}

// MARK: - AudioConversionService + AudioMetadataService round-trip

@Suite("AudioConversionService round-trip")
struct AudioConversionRoundTripTests {

    private enum FixtureError: Error {
        case setupFailed
    }

    /// Builds a short sine-wave source file with real title/artist
    /// metadata, using a completely different code path (AVAudioFile for
    /// the tone, AVAssetExportSession for the metadata-bearing m4a) than
    /// AudioConversionService itself uses — the same "ground truth
    /// independent of the implementation under test" principle the image
    /// app's orientation test follows with its hand-built asymmetric
    /// pixel buffer.
    private static func makeSourceFixture() async throws -> (m4a: URL, workDir: URL) {
        let workDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ConversionRoundTrip-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: workDir, withIntermediateDirectories: true)

        let wavURL = workDir.appendingPathComponent("tone.wav")
        try writeSineWaveWAV(to: wavURL, duration: 1.0, sampleRate: 44_100)

        let m4aURL = workDir.appendingPathComponent("source.m4a")
        try await exportToM4A(source: wavURL, destination: m4aURL, title: "Test Title", artist: "Test Artist")

        return (m4aURL, workDir)
    }

    private static func writeSineWaveWAV(to url: URL, duration: Double, sampleRate: Double) throws {
        guard let pcmFormat = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1) else {
            throw FixtureError.setupFailed
        }
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: pcmFormat, frameCapacity: frameCount) else {
            throw FixtureError.setupFailed
        }
        buffer.frameLength = frameCount

        guard let channelData = buffer.floatChannelData?[0] else { throw FixtureError.setupFailed }
        for frame in 0..<Int(frameCount) {
            let sample = sin(2.0 * Double.pi * 440.0 * Double(frame) / sampleRate)
            channelData[frame] = Float(sample) * 0.4
        }

        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: sampleRate,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsNonInterleaved: false
        ]
        let file = try AVAudioFile(forWriting: url, settings: settings, commonFormat: .pcmFormatFloat32, interleaved: false)
        try file.write(from: buffer)
    }

    private static func exportToM4A(source wavURL: URL, destination m4aURL: URL, title: String, artist: String) async throws {
        let asset = AVURLAsset(url: wavURL)
        guard let session = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            throw FixtureError.setupFailed
        }
        session.outputURL = m4aURL
        session.outputFileType = .m4a

        let titleItem = AVMutableMetadataItem()
        titleItem.identifier = .commonIdentifierTitle
        titleItem.value = title as NSString

        let artistItem = AVMutableMetadataItem()
        artistItem.identifier = .commonIdentifierArtist
        artistItem.value = artist as NSString

        session.metadata = [titleItem, artistItem]

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            session.exportAsynchronously {
                continuation.resume()
            }
        }

        guard session.status == .completed else {
            throw session.error ?? FixtureError.setupFailed
        }
    }

    @Test func convertsToALACAndPreservesMetadata() async throws {
        let (m4aURL, workDir) = try await Self.makeSourceFixture()
        defer { try? FileManager.default.removeItem(at: workDir) }

        let sourceAsset = AVURLAsset(url: m4aURL)
        let metadata = await AudioMetadataService.loadTransferableMetadata(from: sourceAsset)
        #expect(!metadata.isEmpty)

        let destinationURL = workDir.appendingPathComponent("converted.m4a")
        try await AudioConversionService.convert(
            sourceURL: m4aURL, to: .alac, quality: .lossless, destinationURL: destinationURL, metadata: metadata
        )

        #expect(FileManager.default.fileExists(atPath: destinationURL.path))

        let outputAsset = AVURLAsset(url: destinationURL)
        let duration = try await outputAsset.load(.duration)
        #expect(abs(CMTimeGetSeconds(duration) - 1.0) < 0.15)

        let (title, artist) = await AudioMetadataService.loadTitleAndArtist(from: outputAsset)
        #expect(title == "Test Title")
        #expect(artist == "Test Artist")
    }

    @Test func convertsToWAVWithCorrectDuration() async throws {
        let (m4aURL, workDir) = try await Self.makeSourceFixture()
        defer { try? FileManager.default.removeItem(at: workDir) }

        let destinationURL = workDir.appendingPathComponent("converted.wav")
        try await AudioConversionService.convert(
            sourceURL: m4aURL, to: .wav, quality: .lossless, destinationURL: destinationURL, metadata: []
        )

        #expect(FileManager.default.fileExists(atPath: destinationURL.path))
        let duration = try await AVURLAsset(url: destinationURL).load(.duration)
        #expect(abs(CMTimeGetSeconds(duration) - 1.0) < 0.15)
    }

    @Test func lowerQualityTierProducesSmallerAACFile() async throws {
        let (m4aURL, workDir) = try await Self.makeSourceFixture()
        defer { try? FileManager.default.removeItem(at: workDir) }

        let highURL = workDir.appendingPathComponent("high.m4a")
        let lowURL = workDir.appendingPathComponent("low.m4a")

        try await AudioConversionService.convert(
            sourceURL: m4aURL, to: .aac, quality: .lossless, destinationURL: highURL, metadata: []
        )
        try await AudioConversionService.convert(
            sourceURL: m4aURL, to: .aac, quality: .maximumCompression, destinationURL: lowURL, metadata: []
        )

        let highSize = (try? FileManager.default.attributesOfItem(atPath: highURL.path)[.size] as? Int) ?? nil ?? 0
        let lowSize = (try? FileManager.default.attributesOfItem(atPath: lowURL.path)[.size] as? Int) ?? nil ?? 0
        #expect(highSize > lowSize)
    }
}
