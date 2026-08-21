//
//  FilesImporter.swift
//  Good_Audio_Converter
//
//  Native Files-app import (iCloud Drive, on-device, third-party
//  providers), using UIDocumentPickerViewController directly so we get
//  reliable multi-select and security-scoped URL access.
//
//  Accepts the broad `.audio` UTType rather than the narrow set of
//  formats we can *encode* — decode is far more permissive than encode
//  on this platform (e.g. MP3/FLAC play back fine even though this app
//  can't produce them), so import stays broad while output stays
//  restricted to what FormatCapabilityService actually confirms.
//

import SwiftUI
import UniformTypeIdentifiers

struct FilesImporter: UIViewControllerRepresentable {
    let onPicked: ([URL]) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.audio], asCopy: true)
        picker.allowsMultipleSelection = true
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onPicked: onPicked)
    }

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPicked: ([URL]) -> Void

        init(onPicked: @escaping ([URL]) -> Void) {
            self.onPicked = onPicked
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            onPicked(urls)
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            onPicked([])
        }
    }
}
