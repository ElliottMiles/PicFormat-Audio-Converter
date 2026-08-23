//
//  ContentView.swift
//  Good_Audio_Converter
//

import SwiftUI

private enum Stage: Hashable {
    case configure
    case results
}

struct ContentView: View {
    @State private var viewModel = ConverterViewModel()
    @State private var path: [Stage] = []

    @State private var isPresentingFilesImporter = false
    @State private var isPresentingRecorder = false
    @State private var isLoadingImports = false

    var body: some View {
        NavigationStack(path: $path) {
            importStage
                .navigationTitle("Audio Converter")
                .navigationDestination(for: Stage.self) { stage in
                    switch stage {
                    case .configure:
                        ConfigureView(viewModel: viewModel) {
                            path.append(.results)
                        }
                    case .results:
                        ResultsView(viewModel: viewModel)
                    }
                }
        }
    }

    // MARK: - Import stage

    private var importStage: some View {
        ScrollView {
            VStack(spacing: 24) {
                if !viewModel.hasAudio {
                    EmptyImportState()
                        .padding(.top, 40)
                } else {
                    ImportedAudioList(viewModel: viewModel)
                }

                importSourceButtons

                if !viewModel.importIssues.isEmpty {
                    IssuesBanner(title: "Some files couldn't be imported", messages: viewModel.importIssues) {
                        viewModel.importIssues.removeAll()
                    }
                }
            }
            .padding()
        }
        .safeAreaInset(edge: .bottom) {
            if viewModel.hasAudio {
                Button {
                    path.append(.configure)
                } label: {
                    Text("Continue with \(viewModel.importedAudio.count) \(viewModel.importedAudio.count == 1 ? "File" : "Files")")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding()
                .background(.bar)
            }
        }
        .overlay {
            if isLoadingImports {
                ProgressView("Importing…")
                    .padding(24)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
            }
        }
        .fullScreenCover(isPresented: $isPresentingRecorder) {
            AudioRecorderView { url in
                isPresentingRecorder = false
                guard let url else { return }
                Task { await importRecording(url) }
            }
            .ignoresSafeArea()
        }
        .sheet(isPresented: $isPresentingFilesImporter) {
            FilesImporter { urls in
                isPresentingFilesImporter = false
                guard !urls.isEmpty else { return }
                Task { await importFileURLs(urls) }
            }
            .ignoresSafeArea()
        }
    }

    private var importSourceButtons: some View {
        VStack(spacing: 12) {
            Button {
                isPresentingFilesImporter = true
            } label: {
                SourceButtonLabel(systemImage: "folder", title: "Files", subtitle: "Import from Files or iCloud Drive")
            }

            Button {
                isPresentingRecorder = true
            } label: {
                SourceButtonLabel(systemImage: "mic", title: "Record Audio", subtitle: "Capture a new recording")
            }
        }
    }

    // MARK: - Import handling

    private func importFileURLs(_ urls: [URL]) async {
        isLoadingImports = true
        defer { isLoadingImports = false }

        // Task.detached specifically — see ConverterViewModel.convert()
        // for why a plain Task{} wouldn't actually leave the main actor
        // under this project's default actor isolation setting.
        let results = await Task.detached(priority: .userInitiated) {
            await Self.importFiles(from: urls)
        }.value

        viewModel.addAudioItems(results)
    }

    private func importRecording(_ url: URL) async {
        isLoadingImports = true
        defer { isLoadingImports = false }

        let name = "Recording \(Date().formatted(date: .numeric, time: .standard))"
        let result = await Task.detached(priority: .userInitiated) {
            do {
                let audio = try await AudioImportService.importFile(url: url, suggestedName: name)
                return Result<ImportedAudio, Error>.success(audio)
            } catch {
                return Result<ImportedAudio, Error>.failure(error)
            }
        }.value

        viewModel.addAudio(result: result)
    }

    nonisolated private static func importFiles(from urls: [URL]) async -> [Result<ImportedAudio, Error>] {
        var results: [Result<ImportedAudio, Error>] = []
        for url in urls {
            do {
                let audio = try await AudioImportService.importPickedFile(from: url)
                results.append(.success(audio))
            } catch {
                results.append(.failure(error))
            }
        }
        return results
    }
}

private struct SourceButtonLabel: View {
    let systemImage: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: systemImage)
                .font(.title2)
                .frame(width: 44, height: 44)
                .background(.tint.opacity(0.15), in: RoundedRectangle(cornerRadius: 12))
                .foregroundStyle(.tint)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding()
        .background(.thickMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

private struct EmptyImportState: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "waveform.circle")
                .font(.system(size: 48))
                .foregroundStyle(.tint)
            Text("Convert Audio")
                .font(.title2.bold())
            Text("Import audio from Files, or record something new, to get started.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct ImportedAudioList: View {
    var viewModel: ConverterViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("\(viewModel.importedAudio.count) Imported")
                    .font(.headline)
                Spacer()
                Text("\(viewModel.totalDuration.formattedDuration) total")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 8) {
                ForEach(viewModel.importedAudio) { audio in
                    HStack(spacing: 12) {
                        Image(systemName: "waveform")
                            .font(.title3)
                            .foregroundStyle(.tint)
                            .frame(width: 32)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(audio.baseFilename)
                                .font(.subheadline.weight(.medium))
                                .lineLimit(1)
                            Text(audio.subtitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Button {
                            viewModel.removeAudio(audio)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(12)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }
}

struct IssuesBanner: View {
    let title: String
    let messages: [String]
    var onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label(title, systemImage: "exclamationmark.triangle.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.orange)
                Spacer()
                Button("Dismiss", action: onDismiss)
                    .font(.caption)
            }
            ForEach(messages, id: \.self) { message in
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    ContentView()
}
