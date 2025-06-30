//
//  MyProfileView.swift
//  Pods
//
//  Created by Dimi Nunez on 6/30/25.
//

import SwiftUI
import Charts

struct MyProfileView: View {
    @Binding var isAuthenticated: Bool
    @State private var showProfileSettings = false
    @EnvironmentObject var onboarding: OnboardingViewModel
    
    var body: some View {
        NavigationView {
            ZStack {
                Color("iosbg2").edgesIgnoringSafeArea(.all)
                
                if onboarding.isLoadingProfile {
                    ProgressView("Loading profile...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = onboarding.profileError {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 50))
                            .foregroundColor(.orange)
                        
                        Text("Error Loading Profile")
                            .font(.headline)
                        
                        Text(error)
                            .font(.subheadline)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                        
                        Button("Try Again") {
                            Task {
                                await onboarding.fetchProfileData()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                } else {
                    // Use our new unified content view
                    profileContentView
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showProfileSettings = true
                    }) {
                        Image(systemName: "gearshape")
                            .font(.system(size: 18))
                            .foregroundColor(.primary)
                    }
                }
            }
        }
        .sheet(isPresented: $showProfileSettings) {
            NavigationView {
                ProfileView(isAuthenticated: $isAuthenticated)
            }
        }
        .onAppear {
            // Refresh profile data if needed (will check staleness automatically)
            onboarding.refreshProfileDataIfNeeded()
        }
    }
    
    private func basicProfileHeaderView() -> some View {
        VStack(spacing: 16) {
            // Profile Picture Circle
            ZStack {
                Circle()
                    .fill(Color(onboarding.profileColor.isEmpty ? "purple" : onboarding.profileColor))
                    .frame(width: 100, height: 100)
                
                // Show initials as fallback for basic view
                Text(onboarding.profileInitial.isEmpty ? "U" : onboarding.profileInitial)
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(.white)
            }
            
            // Basic User Info
            VStack(spacing: 8) {
                Text(onboarding.username.isEmpty ? "User" : onboarding.username)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text("@\(onboarding.username.isEmpty ? "username" : onboarding.username)")
                    .font(.body)
                    .foregroundColor(.secondary)
                
                if !onboarding.email.isEmpty {
                    Text(onboarding.email)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color("iosnp"))
        .cornerRadius(16)
    }
    
    private func profileHeaderView() -> some View {
        VStack(spacing: 16) {
            // Profile Picture with photo support
            ZStack {
                Circle()
                    .fill(Color(onboarding.profileData?.profileColor ?? onboarding.profileColor))
                    .frame(width: 80, height: 80)
                
                if let profileData = onboarding.profileData {
                    if profileData.profilePhoto == "pfp" {
                        // Use asset image
                        Image("pfp")
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 80, height: 80)
                            .clipShape(Circle())
                    } else if !profileData.profilePhoto.isEmpty {
                        // Use URL image
                        AsyncImage(url: URL(string: profileData.profilePhoto)) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            // Show initials while loading
                            Text(profileData.profileInitial)
                                .font(.system(size: 32, weight: .semibold))
                                .foregroundColor(.white)
                        }
                        .frame(width: 80, height: 80)
                        .clipShape(Circle())
                    } else {
                        // Fallback to initials
                        Text(profileData.profileInitial)
                            .font(.system(size: 32, weight: .semibold))
                            .foregroundColor(.white)
                    }
                } else {
                    // Show basic initials while profile data loads
                    Text(onboarding.profileInitial.isEmpty ? "U" : onboarding.profileInitial)
                        .font(.system(size: 32, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
            
            VStack(spacing: 4) {
                Text(onboarding.profileData?.username ?? onboarding.username)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text(onboarding.profileData?.email ?? onboarding.email)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical)
    }
    

    
    private func caloriesTrendView(profileData: ProfileDataResponse) -> some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("3-Week Calorie Intake")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text("\(profileData.daysLogged) of \(profileData.totalDays) days logged")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            
            if !profileData.calorieTrend3Weeks.isEmpty {
                // Chart
                Chart {
                    ForEach(Array(profileData.calorieTrend3Weeks.enumerated()), id: \.offset) { index, day in
                        LineMark(
                            x: .value("Day", index),
                            y: .value("Calories", day.calories)
                        )
                        .lineStyle(StrokeStyle(lineWidth: 2))
                        .foregroundStyle(Color.purple)
                        
                        if day.calories > 0 {
                            PointMark(
                                x: .value("Day", index),
                                y: .value("Calories", day.calories)
                            )
                            .symbol(.circle)
                            .symbolSize(CGSize(width: 6, height: 6))
                            .foregroundStyle(Color.purple)
                        }
                    }
                    
                    // Average line
                    if profileData.averageCaloriesActiveDays > 0 {
                        RuleMark(y: .value("Average", profileData.averageCaloriesActiveDays))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
                            .foregroundStyle(Color.orange.opacity(0.7))
                    }
                }
                .frame(height: 150)
                .chartYScale(domain: 0...max(3000, profileData.calorieTrend3Weeks.map(\.calories).max() ?? 2000))
                .chartXAxis {
                    AxisMarks(preset: .aligned, position: .bottom) { value in
                        AxisValueLabel {
                            if let index = value.as(Int.self),
                               index >= 0 && index < profileData.calorieTrend3Weeks.count {
                                let day = profileData.calorieTrend3Weeks[index]
                                if let date = Calendar.current.date(from: DateComponents(year: Int(day.date.prefix(4)), 
                                                                                       month: Int(day.date.dropFirst(5).prefix(2)), 
                                                                                       day: Int(day.date.suffix(2)))) {
                                    Text(DateFormatter.dayFormatter.string(from: date))
                                        .font(.caption2)
                                }
                            }
                        }
                    }
                }
                
                // Stats row
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Average (all days)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(Int(profileData.averageDailyCalories)) cal")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Average (logged days)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(Int(profileData.averageCaloriesActiveDays)) cal")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.orange)
                    }
                }
                .padding(.top, 8)
            } else {
                Text("No calorie data available")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(height: 100)
            }
        }
        .padding()
        .background(Color("iosfit"))
        .cornerRadius(12)
    }
    
    private func nutritionGoalsView(profileData: ProfileDataResponse) -> some View {
        VStack(spacing: 16) {
            HStack {
                Text("Nutrition Goals")
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
            }
            
            VStack(spacing: 12) {
                goalRow(title: "Calories", value: Int(profileData.calorieGoal), unit: "cal", color: .blue)
                goalRow(title: "Protein", value: Int(profileData.proteinGoal), unit: "g", color: .red)
                goalRow(title: "Carbs", value: Int(profileData.carbsGoal), unit: "g", color: .orange)
                goalRow(title: "Fat", value: Int(profileData.fatGoal), unit: "g", color: .yellow)
            }
        }
        .padding()
        .background(Color("iosfit"))
        .cornerRadius(12)
    }
    
    private func goalRow(title: String, value: Int, unit: String, color: Color) -> some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            
            Text(title)
                .font(.subheadline)
                .foregroundColor(.primary)
            
            Spacer()
            
            Text("\(value) \(unit)")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
        }
    }
    
    private var profileContentView: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 24) {
                // Profile header
                profileHeaderView()
                
                // Weight card (matching the user's example design)
                if let profileData = onboarding.profileData {
                    weightCardView(profileData: profileData)
                } else if onboarding.isLoadingProfile {
                    // Loading state
                    VStack(spacing: 16) {
                        HStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 100, height: 20)
                            Spacer()
                        }
                        HStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 80, height: 32)
                            Spacer()
                        }
                    }
                    .padding()
                    .background(Color("iosfit"))
                    .cornerRadius(12)
                } else {
                    // Error or no data state
                    VStack(spacing: 8) {
                        Text("Unable to load profile data")
                            .font(.body)
                            .foregroundColor(.secondary)
                        
                        Button("Retry") {
                            Task {
                                await onboarding.fetchProfileData()
                            }
                        }
                        .font(.subheadline)
                        .foregroundColor(.accentColor)
                    }
                    .padding()
                    .background(Color("iosfit"))
                    .cornerRadius(12)
                }
                
                // 3-week calorie trend
                if let profileData = onboarding.profileData {
                    caloriesTrendView(profileData: profileData)
                }
                
                // Nutrition goals
                if let profileData = onboarding.profileData {
                    nutritionGoalsView(profileData: profileData)
                }
                
                Spacer(minLength: 100)
            }
            .padding(.horizontal)
        }
    }
    
    private func weightCardView(profileData: ProfileDataResponse) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("WEIGHT")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.gray)
            
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                if let weightLbs = profileData.currentWeightLbs {
                    Text("\(String(format: "%.1f", weightLbs))")
                        .font(.system(size: 28, weight: .semibold, design: .rounded))
                        .foregroundColor(.primary)
                    Text("lbs")
                        .font(.system(size: 18))
                        .foregroundColor(.gray)
                } else if let weightKg = profileData.currentWeightKg {
                    // Fallback to kg if lbs not available
                    let weightLbs = weightKg * 2.20462
                    Text("\(String(format: "%.1f", weightLbs))")
                        .font(.system(size: 28, weight: .semibold, design: .rounded))
                        .foregroundColor(.primary)
                    Text("lbs")
                        .font(.system(size: 18))
                        .foregroundColor(.gray)
                } else {
                    Text("No data")
                        .font(.system(size: 18))
                        .foregroundColor(.secondary)
                }
            }
            
            if let weightDate = profileData.weightDate {
                Text("Last updated: \(formatDateString(weightDate))")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            } else if profileData.currentWeightKg == nil && profileData.currentWeightLbs == nil {
                Text("Add your first weight entry")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                
                Button("Add Weight") {
                    // TODO: Navigate to add weight view
                    print("TODO: Navigate to add weight")
                }
                .font(.system(size: 14))
                .foregroundColor(.accentColor)
                .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color("iosfit"))
        .cornerRadius(12)
        .onAppear {
            // Debug: Print weight data
            print("🏋️ Weight Debug:")
            print("  - currentWeightKg: \(profileData.currentWeightKg?.description ?? "nil")")
            print("  - currentWeightLbs: \(profileData.currentWeightLbs?.description ?? "nil")")
            print("  - weightDate: \(profileData.weightDate ?? "nil")")
        }
    }
    
    // MARK: - Helper Functions
    
    private func formatDateString(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .medium
            displayFormatter.timeStyle = .none
            return displayFormatter.string(from: date)
        }
        return dateString
    }
}

// MARK: - Extensions

extension DateFormatter {
    static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter
    }()
}

#Preview {
    MyProfileView(isAuthenticated: .constant(true))
}
