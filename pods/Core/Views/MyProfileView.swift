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
    @EnvironmentObject var vm: DayLogsViewModel  // Add this to access current weight
    
    // Weight data state
    @State private var currentWeightLbs: Double? = nil
    @State private var weightDate: String? = nil
    @State private var isLoadingWeight = false
    @State private var recentWeightLogs: [WeightLogResponse] = []
    
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
                            .font(.system(size: 40))
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
            // Fetch weight data using the same method as DashboardView
            fetchWeightData()
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
                weightCardView
                
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
    
    private var weightCardView: some View {
        HStack(spacing: 16) {
            // Left side - Weight info
            VStack(alignment: .leading, spacing: 4) {
                // Title with icon and label like DashboardView
                HStack(spacing: 4) {
                    Image(systemName: "scalemass")
                        .foregroundColor(.purple)
                        .font(.system(size: 16))
                    Text("Weight")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.purple)
                }
                
                Spacer()
                
                // Weight value
                if isLoadingWeight {
                    ProgressView()
                        .scaleEffect(0.8)
                } else if let weightLbs = currentWeightLbs {
                    HStack(alignment: .firstTextBaseline, spacing: 0) {
                        Text("\(String(format: "%.1f", weightLbs))")
                            .font(.system(size: 26, weight: .semibold, design: .rounded))
                            .foregroundColor(.primary)
                        Text(" lbs")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                } else {
                    Text("No data")
                        .font(.system(size: 18))
                        .foregroundColor(.secondary)
                }
                
                // Date with chevron or prompt
                if let weightDate = weightDate {
                    HStack(spacing: 4) {
                        Text(formatWeightLogDate(weightDate))
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                } else if currentWeightLbs == nil && !isLoadingWeight {
                    Text("Add your first weight entry")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Right side - Small trend chart
            if recentWeightLogs.count >= 2 {
                weightTrendChart
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color("iosfit"))
        .cornerRadius(12)
        .onAppear {
            // Debug: Print weight data
            print("🏋️ Weight Debug (Local State):")
            print("  - currentWeightLbs: \(currentWeightLbs?.description ?? "nil")")
            print("  - weightDate: \(weightDate ?? "nil")")
            print("  - vm.weight: \(vm.weight)")
            print("  - recentWeightLogs count: \(recentWeightLogs.count)")
        }
    }
    
    private var weightTrendChart: some View {
        let chartData = Array(recentWeightLogs.enumerated().reversed())
        let weights = chartData.map { $0.1.weightKg * 2.20462 }
        
        // Calculate a better Y-axis range to show variation
        let minWeight = weights.min() ?? 0
        let maxWeight = weights.max() ?? 0
        let range = maxWeight - minWeight
        let padding = max(range * 0.3, 2.0) // At least 2 lbs padding
        let yAxisMin = minWeight - padding
        let yAxisMax = maxWeight + padding
        
        return Chart {
            ForEach(chartData, id: \.offset) { index, log in
                LineMark(
                    x: .value("Day", index),
                    y: .value("Weight", log.weightKg * 2.20462)
                )
                .lineStyle(StrokeStyle(lineWidth: 2))
                .foregroundStyle(Color.purple)
                
                PointMark(
                    x: .value("Day", index),
                    y: .value("Weight", log.weightKg * 2.20462)
                )
                .symbol(.circle)
                .symbolSize(CGSize(width: 4, height: 4))
                .foregroundStyle(Color.purple)
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartYScale(domain: yAxisMin...yAxisMax) // Custom scale to show variation
        .chartLegend(.hidden)
        .frame(width: 80, height: 40)
        .background(Color.clear)
        .onAppear {
            print("🏋️ Chart Data Debug:")
            print("  - Chart data count: \(chartData.count)")
            print("  - Weight range: \(minWeight) to \(maxWeight) lbs")
            print("  - Y-axis scale: \(yAxisMin) to \(yAxisMax)")
            for (index, log) in chartData {
                let weightLbs = log.weightKg * 2.20462
                print("  - Chart point \(index): \(weightLbs)lbs from \(log.dateLogged)")
            }
        }
    }
    
    // MARK: - Helper Functions
    
    private func formatWeightLogDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: dateString) else {
            return dateString
        }
        
        let calendar = Calendar.current
        let now = Date()
        
        if calendar.isDateInToday(date) {
            // Today: show time like "4:19 AM"
            let timeFormatter = DateFormatter()
            timeFormatter.dateFormat = "h:mm a"
            return timeFormatter.string(from: date)
        } else if calendar.isDateInYesterday(date) {
            // Yesterday: show "Yesterday"
            return "Yesterday"
        } else {
            // Other dates: show "Jun 4" format
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "MMM d"
            return dateFormatter.string(from: date)
        }
    }
    
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
    
    private func fetchWeightData() {
        // Always fetch from API to get recent logs for the chart, even if vm has weight
        guard let email = UserDefaults.standard.string(forKey: "userEmail") else {
            print("❌ No user email found for weight fetch")
            return
        }
        
        print("🏋️ Fetching weight data for email: \(email)")
        print("🏋️ vm.weight value: \(vm.weight)")
        
        // If vm has weight, use it immediately but still fetch logs for chart
        if vm.weight > 0 {
            currentWeightLbs = vm.weight * 2.20462
            print("🏋️ Got initial weight from DayLogsViewModel: \(vm.weight)kg = \(currentWeightLbs!)lbs")
        }
        
        isLoadingWeight = true
        NetworkManagerTwo.shared.fetchWeightLogs(userEmail: email, limit: 7, offset: 0) { result in
            DispatchQueue.main.async {
                self.isLoadingWeight = false
                
                switch result {
                case .success(let response):
                    self.recentWeightLogs = response.logs
                    
                    print("🏋️ Weight API Response:")
                    print("  - Total logs received: \(response.logs.count)")
                    print("  - Show chart condition (count >= 2): \(response.logs.count >= 2)")
                    
                    for (index, log) in response.logs.enumerated() {
                        print("  - Log \(index + 1): \(log.weightKg)kg (\(log.weightKg * 2.20462)lbs) on \(log.dateLogged)")
                    }
                    
                    if let mostRecentLog = response.logs.first {
                        self.currentWeightLbs = mostRecentLog.weightKg * 2.20462
                        self.weightDate = mostRecentLog.dateLogged
                        print("🏋️ Got weight from API: \(mostRecentLog.weightKg)kg = \(self.currentWeightLbs!)lbs with \(response.logs.count) recent logs")
                    } else {
                        print("🏋️ No weight logs found")
                        self.currentWeightLbs = nil
                        self.weightDate = nil
                    }
                case .failure(let error):
                    print("❌ Error fetching weight logs: \(error)")
                    self.currentWeightLbs = nil
                    self.weightDate = nil
                    self.recentWeightLogs = []
                }
            }
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
