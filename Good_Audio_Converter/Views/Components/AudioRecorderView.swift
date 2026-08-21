//
//  AudioRecorderView.swift
//  Good_Audio_Converter
//
//  The "Camera" equivalent for this app: a full-screen in-app recorder
//  rather than a picker into another app's library. Permission is
//  requested as soon as the sheet appears, but recording only starts
//  once the user taps the record button, so nothing is captured before
//  they explicitly ask for it.
//

import SwiftUI

struct AudioRecorderView: View {
    var onFinished: (URL?) -> Void

    @State private var recorder = AudioRecorder()

    var body: some View {
        VStack(spacing: 40) {
            Spacer()

            Image(systemName: "waveform")
                .font(.system(size: 40))
                .foregroundStyle(recorder.isRecording ? Color.red : Color.secondary)
                .symbolEffect(.pulse, isActive: recorder.isRecording)

            Text(recorder.formattedElapsed)
                .font(.system(size: 56, weight: .medium, design: .monospaced))
                .monospacedDigit()

            recordButton

            if let failure = recorder.recordingFailed {
                Text(failure)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer()

            HStack {
                Button("Cancel") {
                    recorder.cancel()
                    onFinished(nil)
                }
                .buttonStyle(.bordered)

                Spacer()

                if recorder.hasRecording {
                    Button("Use Recording") {
                        onFinished(recorder.recordingURL)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .controlSize(.large)
            .padding(.horizontal, 32)
            .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
        .task {
            await recorder.requestPermission()
        }
        .alert("Microphone Access Needed", isPresented: $recorder.permissionDenied) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
                onFinished(nil)
            }
            Button("Cancel", role: .cancel) { onFinished(nil) }
        } message: {
            Text("Enable microphone access in Settings to record audio.")
        }
    }

    private var recordButton: some View {
        Button {
            recorder.toggleRecording()
        } label: {
            ZStack {
                Circle()
                    .stroke(Color.primary.opacity(0.2), lineWidth: 4)
                    .frame(width: 84, height: 84)
                RoundedRectangle(cornerRadius: recorder.isRecording ? 8 : 36)
                    .fill(Color.red)
                    .frame(width: recorder.isRecording ? 32 : 68, height: recorder.isRecording ? 32 : 68)
                    .animation(.easeInOut(duration: 0.2), value: recorder.isRecording)
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    AudioRecorderView { _ in }
}
