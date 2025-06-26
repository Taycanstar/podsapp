//
//  CompareWeightLogsView.swift
//  Pods
//
//  Created by Dimi Nunez on 6/25/25.
//

import SwiftUI

struct CompareWeightLogsView: View {
    @Environment(\.dismiss) private var dismiss
    let selectedLogIds: [Int]
    @State private var selectedLogs: [WeightLogResponse] = []
    @State private var isLoading = true
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
                if isLoading {
                    ProgressView("Loading comparison...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if selectedLogs.count == 2 {
                    VStack(spacing: 20) {
                        // View mode controls
                        viewModeControls
                        
                        // Comparison content based on selected mode
                        if viewMode == .sideBySide {
                            sideBySideView
                        } else {
                            beforeAfterView
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
        .onAppear {
            loadSelectedLogs()
        }
    }
    
    private var viewModeControls: some View {
        HStack(spacing: 20) {
            Button(action: {
                viewMode = .sideBySide
            }) {
                Image(systemName: "square.split.2x1")
                    .font(.system(size: 24))
                    .foregroundColor(viewMode == .sideBySide ? .accentColor : .secondary)
            }
            
            Button(action: {
                viewMode = .beforeAfter
            }) {
                Image(systemName: "square.lefthalf.filled")
                    .font(.system(size: 24))
                    .foregroundColor(viewMode == .beforeAfter ? .accentColor : .secondary)
            }
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
                                    .overlay(
                                        // Add fade effect on the right edge of first photo and left edge of second photo
                                        LinearGradient(
                                            gradient: Gradient(stops: [
                                                .init(color: Color.clear, location: index == 0 ? 0.0 : 0.9),
                                                .init(color: Color.black.opacity(0.3), location: index == 0 ? 0.9 : 1.0),
                                                .init(color: Color.clear, location: 1.0)
                                            ]),
                                            startPoint: index == 0 ? .leading : .trailing,
                                            endPoint: index == 0 ? .trailing : .leading
                                        )
                                        .blendMode(.multiply)
                                    )
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
            
            // Weight and date info for both photos
            HStack(spacing: 0) {
                ForEach(selectedLogs.sorted(by: { log1, log2 in
                    // Sort by date - older first
                    guard let date1 = dateFormatter.date(from: log1.dateLogged),
                          let date2 = dateFormatter.date(from: log2.dateLogged) else {
                        return false
                    }
                    return date1 < date2
                }), id: \.id) { log in
                    VStack(spacing: 4) {
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
                    // Background (older photo)
                    if let oldLog = sortedLogs.first,
                       let photoUrl = oldLog.photo, !photoUrl.isEmpty {
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
                    
                    // Foreground (newer photo) with mask
                    if let newLog = sortedLogs.last,
                       let photoUrl = newLog.photo, !photoUrl.isEmpty {
                        AsyncImage(url: URL(string: photoUrl)) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: geometry.size.width, height: geometry.size.height)
                                .clipped()
                                .mask(
                                    Rectangle()
                                        .frame(width: geometry.size.width * sliderPosition)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                )
                        } placeholder: {
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: geometry.size.width * sliderPosition)
                                .frame(maxWidth: .infinity, alignment: .leading)
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
            
            // Weight and date info
            HStack {
                let sortedLogs = selectedLogs.sorted(by: { log1, log2 in
                    // Sort by date - older first
                    guard let date1 = dateFormatter.date(from: log1.dateLogged),
                          let date2 = dateFormatter.date(from: log2.dateLogged) else {
                        return false
                    }
                    return date1 < date2
                })
                
                // Before (older)
                VStack(spacing: 4) {
                    Text("Before")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    if let oldLog = sortedLogs.first {
                        Text("\(Int((oldLog.weightKg * 2.20462).rounded())) lbs")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        if let date = dateFormatter.date(from: oldLog.dateLogged) {
                            Text(formatDate(date))
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                
                // After (newer)
                VStack(spacing: 4) {
                    Text("After")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    if let newLog = sortedLogs.last {
                        Text("\(Int((newLog.weightKg * 2.20462).rounded())) lbs")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        if let date = dateFormatter.date(from: newLog.dateLogged) {
                            Text(formatDate(date))
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal)
        }
    }
    
    private func loadSelectedLogs() {
        // For now, we'll fetch all logs and filter by the selected IDs
        // In a real implementation, you might want to fetch specific logs by ID
        guard let email = UserDefaults.standard.string(forKey: "userEmail") else {
            isLoading = false
            return
        }
        
        NetworkManagerTwo.shared.fetchWeightLogs(userEmail: email, limit: 1000, offset: 0) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let response):
                    self.selectedLogs = response.logs.filter { selectedLogIds.contains($0.id) }
                case .failure:
                    self.selectedLogs = []
                }
                self.isLoading = false
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

#Preview {
    CompareWeightLogsView(selectedLogIds: [1, 2])
}
