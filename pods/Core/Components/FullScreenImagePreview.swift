//
//  FullScreenImagePreview.swift
//  pods
//
//  Created by Dimi Nunez on 1/11/26.
//


//
//  FullScreenImagePreview.swift
//  pods
//
//  Created by Dimi Nunez on 1/11/26.
//

import SwiftUI

/// Full-screen image preview with zoom and pan support (ChatGPT-style)
struct FullScreenImagePreview: View {
    let attachment: ChatAttachment
    let onDismiss: () -> Void

    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @GestureState private var magnifyBy: CGFloat = 1.0

    var body: some View {
        ZStack {
            // Dark background
            Color.black
                .ignoresSafeArea()
                .onTapGesture {
                    onDismiss()
                }

            // Image with zoom/pan
            imageContent
                .scaleEffect(scale * magnifyBy)
                .offset(offset)
                .gesture(
                    MagnifyGesture()
                        .updating($magnifyBy) { value, state, _ in
                            state = value.magnification
                        }
                        .onEnded { value in
                            scale = min(max(scale * value.magnification, 1), 5)
                            if scale == 1 {
                                offset = .zero
                            }
                        }
                )
                .simultaneousGesture(
                    DragGesture()
                        .onChanged { value in
                            if scale > 1 {
                                offset = CGSize(
                                    width: lastOffset.width + value.translation.width,
                                    height: lastOffset.height + value.translation.height
                                )
                            }
                        }
                        .onEnded { _ in
                            lastOffset = offset
                        }
                )
                .onTapGesture(count: 2) {
                    withAnimation(.spring(response: 0.3)) {
                        if scale > 1 {
                            scale = 1
                            offset = .zero
                            lastOffset = .zero
                        } else {
                            scale = 2.5
                        }
                    }
                }

            // Close button
            VStack {
                HStack {
                    Spacer()
                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 32, height: 32)
                            .background(Color.white.opacity(0.2))
                            .clipShape(Circle())
                    }
                    .padding(.trailing, 16)
                    .padding(.top, 8)
                }
                Spacer()
            }
        }
        .statusBarHidden()
    }

    @ViewBuilder
    private var imageContent: some View {
        if let urlString = attachment.remoteURL, let url = URL(string: urlString) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .empty:
                    ProgressView()
                        .tint(.white)
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFit()
                case .failure:
                    VStack(spacing: 12) {
                        Image(systemName: "photo")
                            .font(.system(size: 48))
                            .foregroundColor(.gray)
                        Text("Failed to load image")
                            .foregroundColor(.gray)
                    }
                @unknown default:
                    EmptyView()
                }
            }
        } else if let image = UIImage(data: attachment.data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
        } else {
            VStack(spacing: 12) {
                Image(systemName: "photo")
                    .font(.system(size: 48))
                    .foregroundColor(.gray)
                Text("No image available")
                    .foregroundColor(.gray)
            }
        }
    }
}
