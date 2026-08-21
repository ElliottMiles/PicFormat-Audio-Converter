//
//  DocumentExporter.swift
//  Good_Audio_Converter
//
//  Wraps UIDocumentPickerViewController(forExporting:) directly instead of
//  SwiftUI's .fileExporter modifier. Passing every URL to export in one
//  array — rather than SwiftUI's single-document-at-a-time model — is
//  what makes the system picker copy files straight into the chosen
//  folder for both a lone file and a batch, with no extra wrapping
//  folder created around a single export.
//

import SwiftUI
import UniformTypeIdentifiers

struct DocumentExporter: UIViewControllerRepresentable {
    let urls: [URL]
    let onFinish: (Bool) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forExporting: urls, asCopy: true)
        picker.delegate = context.coordinator
        picker.shouldShowFileExtensions = true
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onFinish: onFinish)
    }

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onFinish: (Bool) -> Void

        init(onFinish: @escaping (Bool) -> Void) {
            self.onFinish = onFinish
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            onFinish(true)
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            onFinish(false)
        }
    }
}
