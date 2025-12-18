//
//  SearchView.swift
//  pods
//
//  Created by Dimi Nunez on 12/17/25.
//

import SwiftUI

struct SearchView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject var vm: DayLogsViewModel
    @State private var showQuickAddSheet = false

    /// Recent food logs (filtered to show only food type logs)
    private var recentFoodLogs: [CombinedLog] {
        vm.logs
            .filter { $0.type == .food }
            .prefix(10)
            .map { $0 }
    }

    var body: some View {
        List {
            // MARK: - Categories Section
            Section {
                SearchCategoryRow(icon: "carrot.fill", title: "Foods", iconColor: .orange)
                SearchCategoryRow(icon: "fork.knife", title: "Recipes", iconColor: .green)
                SearchCategoryRow(icon: "bookmark.fill", title: "Saved", iconColor: .blue)
                SearchCategoryRow(icon: "dumbbell.fill", title: "Workouts", iconColor: .purple)

                Button {
                    showQuickAddSheet = true
                } label: {
                    SearchCategoryRow(icon: "plus.circle.fill", title: "Quick Add", iconColor: .gray)
                }
                .buttonStyle(.plain)
            }

            // MARK: - Recents Section
            if !recentFoodLogs.isEmpty {
                Section {
                    ForEach(recentFoodLogs) { log in
                        RecentFoodRow(log: log)
                    }
                } header: {
                    Text("Recents")
                }
            }
        }
        .navigationTitle("Search")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                }
            }
        }
        .sheet(isPresented: $showQuickAddSheet) {
            QuickAddSheet()
        }
    }
}

// MARK: - Search Category Row

struct SearchCategoryRow: View {
    let icon: String
    let title: String
    let iconColor: Color

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(iconColor)
                .frame(width: 32, alignment: .center)

            Text(title)
                .font(.system(size: 17))
                .foregroundColor(.primary)

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Recent Food Row

struct RecentFoodRow: View {
    let log: CombinedLog

    private var displayName: String {
        log.food?.displayName ?? log.message
    }

    private var caloriesText: String {
        "\(Int(log.displayCalories)) cal"
    }

    private var brandText: String? {
        log.food?.brandText
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(displayName)
                    .font(.system(size: 15))
                    .foregroundColor(.primary)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)

                    Text(caloriesText)
                        .foregroundColor(.secondary)

                    if let brand = brandText, !brand.isEmpty {
                        Text("•")
                            .foregroundColor(.secondary)
                        Text(brand)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                .font(.system(size: 13))
            }

            Spacer()
        }
        .contentShape(Rectangle())
    }
}

#Preview {
    NavigationStack {
        SearchView()
            .environmentObject(DayLogsViewModel())
    }
}
