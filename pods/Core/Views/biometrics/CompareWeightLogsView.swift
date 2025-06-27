//
//  CompareWeightLogsView.swift
//  Pods
//
//  Created by Dimi Nunez on 6/25/25.
//

import SwiftUI

struct CompareWeightLogsView: View {
    @Environment(\.dismiss) private var dismiss
    let selectedLogs: [WeightLogResponse]
    @State private var viewMode: ViewMode = .sideBySide
    @State private var sliderPosition: CGFloat = 0.5 // For before/after slider (0.0 = old photo, 1.0 = new photo)
    
    enum ViewMode {
        case sideBySide
        case beforeAfter
    }
    
    private let dateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
    
    var body: some View {
        NavigationView {
            VStack {
                if selectedLogs.count == 2 {
                    VStack(spacing: 20) {
                        // View mode controls
                        viewModeControls
                            .zIndex(1) // Ensure controls are on top
                        
                        // Comparison content based on selected mode
                        if viewMode == .sideBySide {
                            sideBySideView
                                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                        } else {
                            beforeAfterView
                                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                        }
                        
                        Spacer()
                    }
                    .padding(.top)
                } else {
                    Text("Unable to load comparison data")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationTitle("Compare Photos")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button("Done") {
                dismiss()
            })
        }
    }
    
    private var viewModeControls: some View {
        HStack(spacing: 20) {
            // Side-by-Side Button with enhanced tappable area
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    viewMode = .sideBySide
                }
            }) {
                ZStack {
                    // Larger invisible tappable area
                    Rectangle()
                        .fill(Color.clear)
                        .frame(width: 50, height: 50)
                    
                    // Visual content
                    Image(systemName: "square.split.2x1")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(viewMode == .sideBySide ? .accentColor : .secondary)
                }
                .frame(width: 50, height: 50)
                .background(viewMode == .sideBySide ? Color.accentColor.opacity(0.1) : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .contentShape(Rectangle()) // Ensures entire frame is tappable
            }
            .buttonStyle(PlainButtonStyle())
            
            // Before/After Button
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    viewMode = .beforeAfter
                }
            }) {
                ZStack {
                    // Larger invisible tappable area
                    Rectangle()
                        .fill(Color.clear)
                        .frame(width: 50, height: 50)
                    
                    // Visual content
                    Image(systemName: "square.lefthalf.filled")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(viewMode == .beforeAfter ? .accentColor : .secondary)
                }
                .frame(width: 50, height: 50)
                .background(viewMode == .beforeAfter ? Color.accentColor.opacity(0.1) : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .contentShape(Rectangle()) // Ensures entire frame is tappable
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal)
    }
    
    private var sideBySideView: some View {
        VStack(spacing: 20) {
            // Photos side by side with no space and blend effect
            GeometryReader { geometry in
                HStack(spacing: 0) {
                    ForEach(Array(selectedLogs.sorted(by: { log1, log2 in
                        // Sort by date - older first
                        guard let date1 = dateFormatter.date(from: log1.dateLogged),
                              let date2 = dateFormatter.date(from: log2.dateLogged) else {
                            return false
                        }
                        return date1 < date2
                    }).enumerated()), id: \.element.id) { index, log in
                        // Photo
                        if let photoUrl = log.photo, !photoUrl.isEmpty {
                            AsyncImage(url: URL(string: photoUrl)) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: geometry.size.width / 2)
                                    .clipped()
                            } placeholder: {
                                Rectangle()
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(width: geometry.size.width / 2)
                                    .overlay(
                                        ProgressView()
                                            .scaleEffect(0.8)
                                    )
                            }
                        } else {
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: geometry.size.width / 2)
                                .overlay(
                                    Text("No Photo")
                                        .foregroundColor(.secondary)
                                )
                        }
                    }
                }
            }
            .frame(height: 400)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)
            
            // Weight and date info for both photos with before/after labels
            HStack(spacing: 0) {
                ForEach(Array(selectedLogs.sorted(by: { log1, log2 in
                    // Sort by date - older first
                    guard let date1 = dateFormatter.date(from: log1.dateLogged),
                          let date2 = dateFormatter.date(from: log2.dateLogged) else {
                        return false
                    }
                    return date1 < date2
                }).enumerated()), id: \.element.id) { index, log in
                    VStack(spacing: 4) {
                        Text(index == 0 ? "Before" : "After")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                        
                        Text("\(Int((log.weightKg * 2.20462).rounded())) lbs")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        if let date = dateFormatter.date(from: log.dateLogged) {
                            Text(formatDate(date))
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal)
        }
    }
    
    private var beforeAfterView: some View {
        VStack(spacing: 20) {
            // Before/After slider view
            GeometryReader { geometry in
                let sortedLogs = selectedLogs.sorted(by: { log1, log2 in
                    // Sort by date - older first
                    guard let date1 = dateFormatter.date(from: log1.dateLogged),
                          let date2 = dateFormatter.date(from: log2.dateLogged) else {
                        return false
                    }
                    return date1 < date2
                })
                
                ZStack {
                    // Background (newer photo - shows on the right side)
                    if let newLog = sortedLogs.last,
                       let photoUrl = newLog.photo, !photoUrl.isEmpty {
                        AsyncImage(url: URL(string: photoUrl)) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: geometry.size.width, height: geometry.size.height)
                                .clipped()
                        } placeholder: {
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .overlay(
                                    ProgressView()
                                        .scaleEffect(0.8)
                                )
                        }
                    }
                    
                    // Foreground (older photo - reveals from left) with mask
                    if let oldLog = sortedLogs.first,
                       let photoUrl = oldLog.photo, !photoUrl.isEmpty {
                        AsyncImage(url: URL(string: photoUrl)) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: geometry.size.width, height: geometry.size.height)
                                .clipped()
                                .mask(
                                    HStack(spacing: 0) {
                                        Rectangle()
                                            .frame(width: geometry.size.width * sliderPosition)
                                        Spacer()
                                    }
                                )
                        } placeholder: {
                            HStack(spacing: 0) {
                                Rectangle()
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(width: geometry.size.width * sliderPosition)
                                Spacer()
                            }
                        }
                    }
                    
                    // Slider line
                    Rectangle()
                        .fill(Color.white)
                        .frame(width: 2)
                        .shadow(color: .black.opacity(0.3), radius: 2)
                        .position(x: geometry.size.width * sliderPosition, y: geometry.size.height / 2)
                    
                    // Slider handle
                    Circle()
                        .fill(Color.white)
                        .frame(width: 30, height: 30)
                        .shadow(color: .black.opacity(0.3), radius: 4)
                        .overlay(
                            Image(systemName: "arrow.left.and.right")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.gray)
                        )
                        .position(x: geometry.size.width * sliderPosition, y: geometry.size.height / 2)
                }
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            let newPosition = value.location.x / geometry.size.width
                            sliderPosition = max(0, min(1, newPosition))
                        }
                )
            }
            .frame(height: 400)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)
            
            // Dynamic weight and date info based on which photo is more visible
            VStack(spacing: 4) {
                let sortedLogs = selectedLogs.sorted(by: { log1, log2 in
                    // Sort by date - older first
                    guard let date1 = dateFormatter.date(from: log1.dateLogged),
                          let date2 = dateFormatter.date(from: log2.dateLogged) else {
                        return false
                    }
                    return date1 < date2
                })
                
                // Show info for the more visible photo (sliderPosition > 0.5 means older photo is more visible)
                let dominantLog = sliderPosition > 0.5 ? sortedLogs.first : sortedLogs.last
                
                if let log = dominantLog {
                    Text("\(Int((log.weightKg * 2.20462).rounded())) lbs")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    if let date = dateFormatter.date(from: log.dateLogged) {
                        Text(formatDate(date))
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal)
            .animation(.easeInOut(duration: 0.2), value: sliderPosition > 0.5)
        }
    }
    

    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

#Preview {
    CompareWeightLogsView(selectedLogs: [])
}
