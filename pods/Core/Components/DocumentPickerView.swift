//
//  DocumentPickerView.swift
//  pods
//
//  Created by Dimi Nunez on 1/11/26.
//


//
//  DocumentPickerView.swift
//  pods
//
//  Created by Claude on 1/11/26.
//

import SwiftUI
import UniformTypeIdentifiers

/// Document picker for selecting files from the device
struct DocumentPickerView: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss
    var onDocumentsSelected: ([URL]) -> Void
    var allowMultiple: Bool = true

    /// Supported document types for attachment
    static let supportedTypes: [UTType] = [
        // Documents
        .pdf,
        .plainText,
        .rtf,
        .rtfd,

        // Spreadsheets
        .commaSeparatedText,
        .spreadsheet,

        // Presentations
        .presentation,

        // Data formats
        .json,
        .xml,
        .yaml,

        // Archives
        .zip,
        .gzip,
        .archive,

        // Source code (using generic types)
        .sourceCode,
        .script,

        // Microsoft Office (if available)
        UTType("com.microsoft.word.doc") ?? .data,
        UTType("org.openxmlformats.wordprocessingml.document") ?? .data,
        UTType("com.microsoft.excel.xls") ?? .data,
        UTType("org.openxmlformats.spreadsheetml.sheet") ?? .data,
        UTType("com.microsoft.powerpoint.ppt") ?? .data,
        UTType("org.openxmlformats.presentationml.presentation") ?? .data,

        // Images (as fallback)
        .image,
        .jpeg,
        .png,
        .webP,
    ].compactMap { $0 }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: Self.supportedTypes)
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = allowMultiple
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: DocumentPickerView

        init(_ parent: DocumentPickerView) {
            self.parent = parent
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            // Access security-scoped resources
            var accessibleURLs: [URL] = []

            for url in urls {
                if url.startAccessingSecurityScopedResource() {
                    accessibleURLs.append(url)
                }
            }

            parent.onDocumentsSelected(accessibleURLs)
            parent.dismiss()

            // Stop accessing after a delay to allow processing
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                for url in accessibleURLs {
                    url.stopAccessingSecurityScopedResource()
                }
            }
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            parent.dismiss()
        }
    }
}
