//
//  ConfigureView.swift
//  Good_Audio_Converter
//

import SwiftUI

struct ConfigureView: View {
    @Bindable var viewModel: ConverterViewModel
    var onConverted: () -> Void

    @FocusState private var isFilenameFocused: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                formatSection
                if viewModel.selectedFormat?.supportsVariableQuality == true {
                    qualitySection
                }
                filenameSection

                if !viewModel.conversionIssues.isEmpty {
                    IssuesBanner(title: "Some files couldn't be converted", messages: viewModel.conversionIssues) {
                        viewModel.conversionIssues.removeAll()
                    }
                }
            }
            .padding()
        }
        // `.scrollDismissesKeyboard` only fires on an actual scroll drag;
        // the `simultaneousGesture` below is what also dismisses on a tap
        // directly on a format/quality control without scrolling first —
        // `simultaneous` specifically so it doesn't steal the touch from
        // those controls' own tap handling.
        .scrollDismissesKeyboard(.immediately)
        .simultaneousGesture(TapGesture().onEnded { isFilenameFocused = false })
        .navigationTitle("Choose Format")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            Button {
                isFilenameFocused = false
                Task {
                    await viewModel.convert()
                    if viewModel.hasResults {
                        onConverted()
                    }
                }
            } label: {
                if viewModel.isConverting {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Text("Convert \(viewModel.importedAudio.count) \(viewModel.importedAudio.count == 1 ? "File" : "Files")")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(viewModel.selectedFormat == nil || viewModel.isConverting)
            .padding()
            .background(.bar)
        }
    }

    private var formatSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Output Format")
                .font(.headline)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 10)], spacing: 10) {
                ForEach(AudioFormat.allCases) { format in
                    let isAvailable = FormatCapabilityService.isAvailable(format)
                    Button {
                        viewModel.selectedFormat = format
                    } label: {
                        FormatCard(format: format, isSelected: viewModel.selectedFormat == format, isAvailable: isAvailable)
                    }
                    .buttonStyle(.plain)
                    .disabled(!isAvailable)
                }
            }
        }
    }

    private var qualitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quality")
                .font(.headline)

            VStack(spacing: 8) {
                ForEach(AudioQuality.allCases) { quality in
                    QualityRow(quality: quality, isSelected: viewModel.selectedQuality == quality)
                        .onTapGesture {
                            viewModel.selectedQuality = quality
                        }
                }
            }
        }
    }

    private var filenameSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(viewModel.isBatch ? "Filename Prefix" : "Filename")
                .font(.headline)

            TextField(viewModel.isBatch ? "e.g. Podcast" : "e.g. MyRecording", text: $viewModel.outputBaseName)
                .textFieldStyle(.roundedBorder)
                .autocorrectionDisabled()
                .focused($isFilenameFocused)

            if let format = viewModel.selectedFormat {
                Text(viewModel.isBatch
                     ? "Saved as \(FileExportService.sanitize(viewModel.outputBaseName))-1.\(format.fileExtension), -2.\(format.fileExtension), …"
                     : "Saved as \(FileExportService.sanitize(viewModel.outputBaseName)).\(format.fileExtension)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct FormatCard: View {
    let format: AudioFormat
    let isSelected: Bool
    let isAvailable: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(format.displayName)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.tint)
                }
            }
            Text(isAvailable ? format.shortDescription : "Not available on this device")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isSelected ? Color.accentColor.opacity(0.15) : Color(.secondarySystemBackground))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(isSelected ? Color.accentColor : .clear, lineWidth: 2)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .opacity(isAvailable ? 1 : 0.4)
    }
}

private struct QualityRow: View {
    let quality: AudioQuality
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: quality.systemImageName)
                .font(.title3)
                .foregroundStyle(.tint)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(quality.displayName)
                    .font(.subheadline.weight(.semibold))
                Text(quality.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                .foregroundStyle(isSelected ? Color.accentColor : Color(.tertiaryLabel))
        }
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    NavigationStack {
        ConfigureView(viewModel: ConverterViewModel()) {}
    }
}
