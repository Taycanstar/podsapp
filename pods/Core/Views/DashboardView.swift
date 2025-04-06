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
        ZStack {
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
                            
                            // Show food analysis card if analysis is in progress
                            if foodManager.isAnalyzingFood {
                                FoodAnalysisCard()
                                    .padding(.horizontal)
                                    .transition(.opacity)
                            }
                            
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
                .animation(.default, value: foodManager.isAnalyzingFood)
            }
            
            // AI Generation Success Toast
                if foodManager.showAIGenerationSuccess, let food = foodManager.aiGeneratedFood {
                    VStack{
                        Spacer ()
                        BottomPopup(message: "Food logged")
                                     .padding(.bottom, 0)
                    }
            
              .zIndex(100)
              .transition(.opacity)
                .animation(.spring(), value: foodManager.showAIGenerationSuccess)

                }
        
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

// Food analysis card that shows the animated analysis UI
struct FoodAnalysisCard: View {
    @EnvironmentObject var foodManager: FoodManager
    @State private var animateProgress = false
    
    var analysisTitle: String {
        switch foodManager.analysisStage {
        case 0: return "Analyzing Food..."
        case 1: return "Separating Ingredients..."
        case 2: return "Breaking down macros..."
        case 3: return "Finishing Analysis..."
        default: return "Analyzing Food..."
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(analysisTitle)
                .font(.headline)
                .fontWeight(.semibold)
                .transition(.opacity)
                .animation(.easeInOut, value: foodManager.analysisStage)
            
            // Progress bars
            VStack(spacing: 12) {
                ProgressBar(width: animateProgress ? 0.9 : 0.3, delay: 0)
                ProgressBar(width: animateProgress ? 0.7 : 0.5, delay: 0.2)
                ProgressBar(width: animateProgress ? 0.8 : 0.4, delay: 0.4)
            }
            
            Text("We'll notify you when done!")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 10)
        }
        .padding()
        .background(Color("iosnp"))
        .cornerRadius(12)
        .onAppear {
            startAnimation()
        }
        .onChange(of: foodManager.analysisStage) { _ in
            // Restart animation for each stage
            startAnimation()
        }
    }
    
    private func startAnimation() {
        animateProgress = false
        withAnimation(.easeIn(duration: 0.3)) {
            animateProgress = true
        }
        
        // Cycle the animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(.easeOut(duration: 0.3)) {
                animateProgress = false
            }
        }
    }
}

// Animated progress bar component
struct ProgressBar: View {
    var width: CGFloat
    var delay: Double
    
    @State private var animate = false
    
    var body: some View {
        GeometryReader { geometry in
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.gray.opacity(0.2))
                .frame(height: 8)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.accentColor)
                        .frame(width: geometry.size.width * width, height: 8, alignment: .leading)
                )
        }
        .frame(height: 8)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                withAnimation(.spring(response: 0.6)) {
                    animate = true
                }
            }
        }
    }
}
