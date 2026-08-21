//
//  ResultsView.swift
//  Good_Audio_Converter
//
//  Simpler bottom bar than the image app's: there's no Photos-equivalent
//  second save destination for arbitrary audio files, so Save goes
//  straight to the Files picker with no destination-chooser dialog.
//

import SwiftUI

struct ResultsView: View {
    @Bindable var viewModel: ConverterViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                summaryCard
                resultsList
            }
            .padding()
        }
        .navigationTitle("Converted")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 10) {
                if let message = viewModel.saveConfirmationMessage {
                    Text(message)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.green)
                }
                HStack(spacing: 12) {
                    Button {
                        viewModel.isPresentingSaveSheet = true
                    } label: {
                        Label("Save", systemImage: "square.and.arrow.down")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)

                    Button {
                        viewModel.isPresentingShareSheet = true
                    } label: {
                        Label("Share", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
                .controlSize(.large)
            }
            .padding()
            .background(.bar)
        }
        .sheet(isPresented: $viewModel.isPresentingSaveSheet) {
            DocumentExporter(urls: viewModel.exportURLs) { success in
                viewModel.isPresentingSaveSheet = false
                viewModel.handleSaveCompletion(success: success)
            }
            .ignoresSafeArea()
        }
        .sheet(isPresented: $viewModel.isPresentingShareSheet) {
            ShareSheet(items: viewModel.exportURLs)
        }
        .onDisappear {
            viewModel.previewPlayer.stop()
        }
    }

    private var summaryCard: some View {
        let saved = viewModel.totalOriginalBytes - viewModel.totalConvertedBytes
        return VStack(alignment: .leading, spacing: 6) {
            Text("\(viewModel.conversionResults.count) file\(viewModel.conversionResults.count == 1 ? "" : "s") converted to \(viewModel.selectedFormat?.displayName ?? "")")
                .font(.headline)
            Text(ByteCountFormatter.string(fromByteCount: Int64(viewModel.totalConvertedBytes), countStyle: .file) + " total"
                 + (saved > 0 ? " · \(ByteCountFormatter.string(fromByteCount: Int64(saved), countStyle: .file)) smaller than originals" : ""))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    private var resultsList: some View {
        VStack(spacing: 10) {
            ForEach(viewModel.conversionResults) { result in
                HStack(spacing: 12) {
                    PlayButton(result: result, player: viewModel.previewPlayer)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(result.filename)
                            .font(.subheadline.weight(.medium))
                            .lineLimit(1)
                        Text("\(result.formattedDuration) · \(result.formattedByteCount)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()
                }
                .padding(12)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }
}

private struct PlayButton: View {
    let result: ConversionResult
    var player: AudioPreviewPlayer

    private var isPlaying: Bool { player.currentlyPlayingID == result.id }

    var body: some View {
        Button {
            player.toggle(id: result.id, url: result.fileURL)
        } label: {
            Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                .font(.system(size: 30))
                .foregroundStyle(.tint)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationStack {
        ResultsView(viewModel: ConverterViewModel())
    }
}
