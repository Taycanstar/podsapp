//
//  DashboardView.swift
//  Pods
//
//  Created by Dimi Nunez on 1/26/25.
//

import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var podsViewModel: PodsViewModel
    @EnvironmentObject var viewModel: OnboardingViewModel
    @EnvironmentObject var foodManager: FoodManager
    @Environment(\.isTabBarVisible) var isTabBarVisible
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Dashboard")
                    .font(.title)
                    .fontWeight(.bold)
                    .padding(.horizontal)
                
                // Log Food button
                Button(action: {
                    viewModel.showFoodContainer()
                }) {
                    HStack {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Log Food")
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.accentColor)
                    .cornerRadius(10)
                }
                .padding(.horizontal)
                
                // Recent logs section
                if !foodManager.combinedLogs.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Recent Logs")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        ForEach(Array(foodManager.combinedLogs.prefix(5)), id: \.id) { log in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(getLogName(log))
                                        .fontWeight(.medium)
                                    if let date = getLogDate(log) {
                                        Text(formatDate(date))
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                
                                Spacer()
                                
                                HStack {
                                    Image(systemName: "flame.fill")
                                        .foregroundColor(.orange)
                                    Text("\(Int(log.displayCalories)) cal")
                                }
                                .font(.subheadline)
                            }
                            .padding()
                            .background(Color("iosnp"))
                            .cornerRadius(10)
                            .padding(.horizontal)
                        }
                    }
                }
            }
            .padding(.vertical)
        }
        .onAppear {
            isTabBarVisible.wrappedValue = true
            podsViewModel.initialize(email: viewModel.email)
            print("🏠 DashboardView onAppear - initializing FoodManager")
            foodManager.initialize(userEmail: viewModel.email)
            
            // Add a slight delay to ensure initialization completes first
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                print("🔄 DashboardView explicitly refreshing logs")
                foodManager.refresh()
            }
        }
    }
    
    // Helper function to get the display name for a log
    private func getLogName(_ log: CombinedLog) -> String {
        switch log.type {
        case .food:
            return log.food?.displayName ?? "Food"
        case .meal:
            return log.meal?.title ?? "Meal"
        case .recipe:
            return log.recipe?.title ?? "Recipe"
        }
    }
    
    // Helper function to get the date for a log
    private func getLogDate(_ log: CombinedLog) -> Date? {
        return log.scheduledAt
    }
    
    // Helper function to format a date
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
