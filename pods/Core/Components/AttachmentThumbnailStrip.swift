//
//  AttachmentThumbnailStrip.swift
//  pods
//
//  Created by Dimi Nunez on 1/11/26.
//


//
//  AttachmentThumbnailStrip.swift
//  pods
//
//  Created by Claude on 1/11/26.
//

import SwiftUI

/// Horizontal strip showing attachment thumbnails with remove buttons
struct AttachmentThumbnailStrip: View {
    @Binding var attachments: [ChatAttachment]
    let maxAttachments: Int = 10

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(attachments) { attachment in
                    AttachmentThumbnailItem(
                        attachment: attachment,
                        onRemove: {
                            withAnimation(.easeOut(duration: 0.2)) {
                                attachments.removeAll { $0.id == attachment.id }
                            }
                        }
                    )
                }
            }
            .padding(.horizontal, 4)
        }
        .frame(height: 80)
    }

    var canAddMore: Bool {
        attachments.count < maxAttachments
    }

    var remainingSlots: Int {
        max(0, maxAttachments - attachments.count)
    }
}

// MARK: - Thumbnail Item

private struct AttachmentThumbnailItem: View {
    let attachment: ChatAttachment
    let onRemove: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            thumbnailContent
                .frame(width: 72, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                )

            // Remove button - inside the thumbnail
            Button(action: onRemove) {
                ZStack {
                    Circle()
                        .fill(Color.black.opacity(0.7))
                        .frame(width: 22, height: 22)
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            .offset(x: -4, y: 4)
        }
    }

    @ViewBuilder
    private var thumbnailContent: some View {
        if attachment.type == .image, let thumbnail = attachment.thumbnail {
            Image(uiImage: thumbnail)
                .resizable()
                .scaledToFill()
        } else if attachment.type == .image, let image = UIImage(data: attachment.data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else {
            // Document thumbnail
            documentThumbnail
        }
    }

    private var documentThumbnail: some View {
        VStack(spacing: 6) {
            Image(systemName: attachment.documentIcon)
                .font(.system(size: 24))
                .foregroundColor(.accentColor)

            Text(fileExtension)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGray6))
    }

    private var fileExtension: String {
        let ext = (attachment.filename as NSString).pathExtension.uppercased()
        return ext.isEmpty ? "FILE" : ext
    }
}

// MARK: - Compact Count Badge (alternative display)

struct AttachmentCountBadge: View {
    let count: Int

    var body: some View {
        if count > 0 {
            Text("\(count)")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 18, height: 18)
                .background(Color.accentColor)
                .clipShape(Circle())
        }
    }
}

// MARK: - Preview

#Preview {
    struct PreviewContainer: View {
        @State private var attachments: [ChatAttachment] = []

        var body: some View {
            VStack {
                if !attachments.isEmpty {
                    AttachmentThumbnailStrip(attachments: $attachments)
                        .padding()
                        .background(Color(.systemGray5))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                Button("Add Sample Image") {
                    if let image = UIImage(systemName: "photo.fill") {
                        if let attachment = ChatAttachment.fromImage(image, filename: "sample.jpg") {
                            attachments.append(attachment)
                        }
                    }
                }
                .padding()
            }
            .padding()
        }
    }

    return PreviewContainer()
}
