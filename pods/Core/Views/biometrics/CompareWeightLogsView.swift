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
                    comparisonView
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
    
    private var comparisonView: some View {
        VStack(spacing: 20) {
            // Photos side by side
            HStack(spacing: 16) {
                ForEach(selectedLogs.sorted(by: { log1, log2 in
                    // Sort by date - older first
                    guard let date1 = dateFormatter.date(from: log1.dateLogged),
                          let date2 = dateFormatter.date(from: log2.dateLogged) else {
                        return false
                    }
                    return date1 < date2
                }), id: \.id) { log in
                    VStack(spacing: 12) {
                        // Photo
                        if let photoUrl = log.photo, !photoUrl.isEmpty {
                            AsyncImage(url: URL(string: photoUrl)) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                            } placeholder: {
                                Rectangle()
                                    .fill(Color.gray.opacity(0.3))
                                    .overlay(
                                        ProgressView()
                                            .scaleEffect(0.8)
                                    )
                            }
                            .frame(maxHeight: 300)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        } else {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.gray.opacity(0.3))
                                .frame(height: 300)
                                .overlay(
                                    Text("No Photo")
                                        .foregroundColor(.secondary)
                                )
                        }
                        
                        // Weight and date info
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
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal)
            
            Spacer()
        }
        .padding(.top)
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
