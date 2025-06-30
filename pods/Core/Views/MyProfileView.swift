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
    @EnvironmentObject var viewModel: OnboardingViewModel
    
    var body: some View {
        NavigationView {
            ZStack {
                Color("iosbg2").edgesIgnoringSafeArea(.all)
                
                if viewModel.isLoadingProfile {
                    ProgressView("Loading profile...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = viewModel.profileError {
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
                            viewModel.fetchProfileData()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                } else if let profile = viewModel.profileData {
                    ScrollView {
                        VStack(spacing: 20) {
                            profileHeaderView(profile: profile)
                            
                            profileStatsView(profile: profile)
                            
                            caloriesTrendView(profile: profile)
                            
                            nutritionGoalsView(profile: profile)
                        }
                        .padding()
                    }
                } else {
                    // Show basic profile info from viewModel even if full profile data isn't loaded
                    ScrollView {
                        VStack(spacing: 20) {
                            basicProfileHeaderView()
                            
                            Text("Loading additional profile data...")
                                .foregroundColor(.secondary)
                                .padding()
                        }
                        .padding()
                    }
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
            viewModel.refreshProfileDataIfNeeded()
        }
    }
    
    private func basicProfileHeaderView() -> some View {
        VStack(spacing: 16) {
            // Profile Picture Circle
            ZStack {
                Circle()
                    .fill(Color(viewModel.profileColor.isEmpty ? "purple" : viewModel.profileColor))
                    .frame(width: 100, height: 100)
                
                // Show initials as fallback for basic view
                Text(viewModel.profileInitial.isEmpty ? "U" : viewModel.profileInitial)
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(.white)
            }
            
            // Basic User Info
            VStack(spacing: 8) {
                Text(viewModel.username.isEmpty ? "User" : viewModel.username)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text("@\(viewModel.username.isEmpty ? "username" : viewModel.username)")
                    .font(.body)
                    .foregroundColor(.secondary)
                
                if !viewModel.email.isEmpty {
                    Text(viewModel.email)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color("iosnp"))
        .cornerRadius(16)
    }
    
    private func profileHeaderView(profile: ProfileDataResponse) -> some View {
        VStack(spacing: 16) {
            // Profile Picture with photo support
            ZStack {
                Circle()
                    .fill(Color(profile.profileColor))
                    .frame(width: 80, height: 80)
                
                if profile.profilePhoto == "pfp" {
                    // Use asset image
                    Image("pfp")
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 80, height: 80)
                        .clipShape(Circle())
                } else if !profile.profilePhoto.isEmpty {
                    // Use URL image
                    AsyncImage(url: URL(string: profile.profilePhoto)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        // Show initials while loading
                        Text(profile.profileInitial)
                            .font(.system(size: 32, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    .frame(width: 80, height: 80)
                    .clipShape(Circle())
                } else {
                    // Fallback to initials
                    Text(profile.profileInitial)
                        .font(.system(size: 32, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
            
            VStack(spacing: 4) {
                Text(profile.username)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text(profile.email)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical)
    }
    
    private func profileStatsView(profile: ProfileDataResponse) -> some View {
        VStack(spacing: 16) {
            HStack {
                Text("Current Stats")
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
            }
            
            HStack(spacing: 20) {
                // Weight Card
                VStack(spacing: 8) {
                    Image(systemName: "scalemass")
                        .font(.system(size: 24))
                        .foregroundColor(.blue)
                    
                    if let weightLbs = profile.currentWeightLbs {
                        Text("\(Int(weightLbs.rounded())) lbs")
                            .font(.title3)
                            .fontWeight(.semibold)
                    } else {
                        Text("No data")
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                    
                    Text("Weight")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color("iosfit"))
                .cornerRadius(12)
                
                // Height Card
                VStack(spacing: 8) {
                    Image(systemName: "ruler")
                        .font(.system(size: 24))
                        .foregroundColor(.green)
                    
                    if let heightFeet = profile.heightFeet, let heightInches = profile.heightInches {
                        Text("\(heightFeet)'\(heightInches)\"")
                            .font(.title3)
                            .fontWeight(.semibold)
                    } else if let heightCm = profile.heightCm {
                        Text("\(Int(heightCm)) cm")
                            .font(.title3)
                            .fontWeight(.semibold)
                    } else {
                        Text("No data")
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                    
                    Text("Height")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color("iosfit"))
                .cornerRadius(12)
            }
        }
    }
    
    private func caloriesTrendView(profile: ProfileDataResponse) -> some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("3-Week Calorie Intake")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text("\(profile.daysLogged) of \(profile.totalDays) days logged")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            
            if !profile.calorieTrend3Weeks.isEmpty {
                // Chart
                Chart {
                    ForEach(Array(profile.calorieTrend3Weeks.enumerated()), id: \.offset) { index, day in
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
                    if profile.averageCaloriesActiveDays > 0 {
                        RuleMark(y: .value("Average", profile.averageCaloriesActiveDays))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
                            .foregroundStyle(Color.orange.opacity(0.7))
                    }
                }
                .frame(height: 150)
                .chartYScale(domain: 0...max(3000, profile.calorieTrend3Weeks.map(\.calories).max() ?? 2000))
                .chartXAxis {
                    AxisMarks(preset: .aligned, position: .bottom) { value in
                        AxisValueLabel {
                            if let index = value.as(Int.self),
                               index >= 0 && index < profile.calorieTrend3Weeks.count {
                                let day = profile.calorieTrend3Weeks[index]
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
                        Text("\(Int(profile.averageDailyCalories)) cal")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Average (logged days)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(Int(profile.averageCaloriesActiveDays)) cal")
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
    
    private func nutritionGoalsView(profile: ProfileDataResponse) -> some View {
        VStack(spacing: 16) {
            HStack {
                Text("Nutrition Goals")
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
            }
            
            VStack(spacing: 12) {
                goalRow(title: "Calories", value: Int(profile.calorieGoal), unit: "cal", color: .blue)
                goalRow(title: "Protein", value: Int(profile.proteinGoal), unit: "g", color: .red)
                goalRow(title: "Carbs", value: Int(profile.carbsGoal), unit: "g", color: .orange)
                goalRow(title: "Fat", value: Int(profile.fatGoal), unit: "g", color: .yellow)
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
