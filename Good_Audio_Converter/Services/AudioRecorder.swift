//
//  AudioRecorder.swift
//  Good_Audio_Converter
//
//  Drives in-app microphone capture — the "Camera" equivalent for this
//  app. Records straight to an AAC .m4a file on disk (no in-memory
//  buffering), so a finished recording is already in the same
//  file-reference shape ImportedAudio expects everywhere else.
//

import AVFoundation
import Observation

@Observable
@MainActor
final class AudioRecorder: NSObject {
    private(set) var isRecording = false
    private(set) var elapsed: TimeInterval = 0
    private(set) var recordingURL: URL?
    var permissionDenied = false
    var recordingFailed: String?

    private var recorder: AVAudioRecorder?
    private var timer: Timer?
    private var permissionGranted = false

    var hasRecording: Bool { recordingURL != nil && !isRecording }
    var formattedElapsed: String { elapsed.formattedDuration }

    func requestPermission() async {
        permissionGranted = await AVAudioApplication.requestRecordPermission()
        if !permissionGranted {
            permissionDenied = true
        }
    }

    func toggleRecording() {
        isRecording ? stop() : start()
    }

    private func start() {
        guard permissionGranted else {
            permissionDenied = true
            return
        }

        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, options: [.defaultToSpeaker])
            try session.setActive(true)
        } catch {
            recordingFailed = "Couldn't start recording: \(error.localizedDescription)"
            return
        }

        let recordingsDir = FileManager.default.temporaryDirectory.appendingPathComponent("Recordings", isDirectory: true)
        try? FileManager.default.createDirectory(at: recordingsDir, withIntermediateDirectories: true)
        let url = recordingsDir.appendingPathComponent("Recording-\(Int(Date().timeIntervalSince1970)).m4a")

        // AAC, not a lossless format: recordings can run long, and this
        // keeps them from silently eating a lot of scratch-disk space
        // before the user even gets to the format picker.
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 2,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        do {
            let newRecorder = try AVAudioRecorder(url: url, settings: settings)
            newRecorder.delegate = self
            guard newRecorder.record() else {
                recordingFailed = "Couldn't start recording."
                return
            }
            recorder = newRecorder
            recordingURL = url
            isRecording = true
            elapsed = 0
            startTimer()
        } catch {
            recordingFailed = "Couldn't start recording: \(error.localizedDescription)"
        }
    }

    private func stop() {
        recorder?.stop()
        recorder = nil
        isRecording = false
        stopTimer()
    }

    func cancel() {
        recorder?.stop()
        recorder = nil
        if let recordingURL {
            try? FileManager.default.removeItem(at: recordingURL)
        }
        recordingURL = nil
        isRecording = false
        elapsed = 0
        stopTimer()
    }

    /// `Timer.scheduledTimer` fires on the run loop it was scheduled
    /// from — the main run loop, since this is only ever called from a
    /// MainActor method — so `assumeIsolated` reflects a real guarantee
    /// here rather than papering over one, and updates `elapsed`
    /// synchronously instead of bouncing through an extra `Task` hop.
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, let recorder = self.recorder else { return }
                self.elapsed = recorder.currentTime
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}

extension AudioRecorder: AVAudioRecorderDelegate {}
