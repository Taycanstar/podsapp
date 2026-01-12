//
//  ChatAttachment.swift
//  pods
//
//  Created by Dimi Nunez on 1/11/26.
//


//
//  ChatAttachment.swift
//  pods
//
//  Created by Claude on 1/11/26.
//

import SwiftUI
import UIKit

/// Represents an attachment (image or document) for agent chat messages
struct ChatAttachment: Identifiable, Equatable {
    let id: UUID
    let type: AttachmentType
    let data: Data
    let filename: String
    let thumbnail: UIImage?
    let mediaType: String
    /// Remote URL for attachments loaded from server (nil for local/new attachments)
    var remoteURL: String?

    enum AttachmentType: String, Equatable {
        case image
        case document
    }

    init(
        id: UUID = UUID(),
        type: AttachmentType,
        data: Data,
        filename: String,
        thumbnail: UIImage? = nil,
        mediaType: String? = nil,
        remoteURL: String? = nil
    ) {
        self.id = id
        self.type = type
        self.data = data
        self.filename = filename
        self.thumbnail = thumbnail
        self.mediaType = mediaType ?? ChatAttachment.inferMediaType(from: filename, type: type)
        self.remoteURL = remoteURL
    }

    /// Create attachment from UIImage
    static func fromImage(_ image: UIImage, filename: String? = nil) -> ChatAttachment? {
        guard let data = image.jpegData(compressionQuality: 0.8) else { return nil }
        let name = filename ?? "photo_\(UUID().uuidString.prefix(8)).jpg"
        return ChatAttachment(
            type: .image,
            data: data,
            filename: name,
            thumbnail: image.preparingThumbnail(of: CGSize(width: 120, height: 120)),
            mediaType: "image/jpeg"
        )
    }

    /// Create attachment from file URL
    static func fromURL(_ url: URL) -> ChatAttachment? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        let filename = url.lastPathComponent
        let ext = url.pathExtension.lowercased()

        let type: AttachmentType = isImageExtension(ext) ? .image : .document
        var thumbnail: UIImage? = nil

        if type == .image, let image = UIImage(data: data) {
            thumbnail = image.preparingThumbnail(of: CGSize(width: 120, height: 120))
        }

        return ChatAttachment(
            type: type,
            data: data,
            filename: filename,
            thumbnail: thumbnail
        )
    }

    /// Infer MIME type from filename
    private static func inferMediaType(from filename: String, type: AttachmentType) -> String {
        let ext = (filename as NSString).pathExtension.lowercased()

        switch ext {
        // Images
        case "jpg", "jpeg": return "image/jpeg"
        case "png": return "image/png"
        case "gif": return "image/gif"
        case "webp": return "image/webp"
        case "heic": return "image/heic"

        // Documents
        case "pdf": return "application/pdf"
        case "doc": return "application/msword"
        case "docx": return "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
        case "xls": return "application/vnd.ms-excel"
        case "xlsx": return "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
        case "csv": return "text/csv"
        case "ppt": return "application/vnd.ms-powerpoint"
        case "pptx": return "application/vnd.openxmlformats-officedocument.presentationml.presentation"
        case "txt": return "text/plain"
        case "md": return "text/markdown"
        case "rtf": return "application/rtf"
        case "json": return "application/json"
        case "xml": return "application/xml"
        case "yaml", "yml": return "application/x-yaml"
        case "sql": return "application/sql"
        case "zip": return "application/zip"
        case "tar": return "application/x-tar"
        case "gz": return "application/gzip"

        // Source code
        case "py": return "text/x-python"
        case "js": return "text/javascript"
        case "ts": return "text/typescript"
        case "swift": return "text/x-swift"
        case "java": return "text/x-java"
        case "cpp", "cc", "cxx": return "text/x-c++src"
        case "c": return "text/x-csrc"
        case "h": return "text/x-chdr"
        case "html": return "text/html"
        case "css": return "text/css"
        case "ipynb": return "application/x-ipynb+json"

        default:
            return type == .image ? "image/jpeg" : "application/octet-stream"
        }
    }

    /// Check if extension is an image type
    private static func isImageExtension(_ ext: String) -> Bool {
        ["jpg", "jpeg", "png", "gif", "webp", "heic", "tiff", "bmp"].contains(ext)
    }

    /// Document icon SF Symbol based on file type
    var documentIcon: String {
        let ext = (filename as NSString).pathExtension.lowercased()
        switch ext {
        case "pdf": return "doc.richtext"
        case "doc", "docx": return "doc.text"
        case "xls", "xlsx", "csv": return "tablecells"
        case "ppt", "pptx": return "rectangle.split.3x1"
        case "txt", "md", "rtf": return "doc.plaintext"
        case "json", "xml", "yaml", "yml": return "curlybraces"
        case "zip", "tar", "gz": return "doc.zipper"
        case "py", "js", "ts", "swift", "java", "cpp", "c", "h": return "chevron.left.forwardslash.chevron.right"
        default: return "doc"
        }
    }

    static func == (lhs: ChatAttachment, rhs: ChatAttachment) -> Bool {
        lhs.id == rhs.id
    }
}
