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
    
    // Sheet states
    @State private var showEditWeightSheet = false
    
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
            .navigationTitle("")
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
        .sheet(isPresented: $showEditWeightSheet) {
            EditWeightView(onWeightSaved: {
                // Refresh weight data after saving with a small delay
                print("🏋️ Weight saved callback received")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    fetchWeightData()
                }
            })
        }
        .onAppear {
            // Refresh profile data if needed (will check staleness automatically)
            onboarding.refreshProfileDataIfNeeded()
            // Fetch weight data using the same method as DashboardView
            fetchWeightData()
            
            // Debug profile data
            if let profileData = onboarding.profileData {
                print("🏥 ===== PROFILE DATA DEBUG =====")
                print("🏥 heightCm: \(profileData.heightCm?.description ?? "nil")")
                print("🏥 heightFeet: \(profileData.heightFeet?.description ?? "nil")")
                print("🏥 heightInches: \(profileData.heightInches?.description ?? "nil")")
                print("🏥 currentWeightKg: \(profileData.currentWeightKg?.description ?? "nil")")
                print("🏥 currentWeightLbs: \(profileData.currentWeightLbs?.description ?? "nil")")
                print("🏥 weightDate: \(profileData.weightDate ?? "nil")")
                print("🏥 email: \(profileData.email)")
                print("🏥 username: \(profileData.username)")
                print("🏥 =============================")
            } else {
                print("🏥 ❌ No profile data available - onboarding.profileData is nil")
                print("🏥 ❌ This means the API call to get_profile_data failed or returned no data")
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("WeightLoggedNotification"))) { _ in
            // Refresh weight data when a new weight is logged
            print("🏋️ Received WeightLoggedNotification - refreshing weight data")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                // Small delay to allow server to update
                fetchWeightData()
            }
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
    
    private func bmiGaugeView(profileData: ProfileDataResponse) -> some View {
        VStack(spacing: 16) {
            HStack {
                Text("Body Mass Index")
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
            }

            ArcOne()
            
  
        }
        .padding()
        .background(Color("iosfit"))
        .cornerRadius(12)
    }
    
    private func calculateBMI(weightKg: Double?, heightCm: Double?) -> Double? {
        print("🏥 calculateBMI called with weightKg: \(weightKg?.description ?? "nil"), heightCm: \(heightCm?.description ?? "nil")")
        
        // Debug: Check what we have
        if weightKg == nil && heightCm == nil {
            print("🏥 Both weight and height are missing from profile data")
        } else if weightKg == nil {
            print("🏥 Weight is missing from profile data (but height exists: \(heightCm!)cm)")
        } else if heightCm == nil {
            print("🏥 Height is missing from profile data (but weight exists: \(weightKg!)kg)")
        }
        
        guard let weight = weightKg, let height = heightCm, weight > 0, height > 0 else {
            print("🏥 calculateBMI returning nil - missing or invalid data")
            return nil
        }
        
        let heightInMeters = height / 100.0
        let bmi = weight / (heightInMeters * heightInMeters)
        print("🏥 calculateBMI returning BMI: \(bmi)")
        return bmi
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
                
                // BMI gauge
                if let profileData = onboarding.profileData {
                    bmiGaugeView(profileData: profileData)
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
    
    private var weightCardView: some View {
        NavigationLink(destination: WeightDataView()) {
            weightCardContent
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var weightCardContent: some View {
        VStack(spacing: 12) {
            // Top row: Weight label on left, date + chevron on right
            HStack {
                // Weight label with icon and plus button
                HStack(spacing: 6) {
                    Image(systemName: "scalemass")
                        .foregroundColor(.purple)
                        .font(.system(size: 16))
                    Text("Weight")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.purple)
                    
                    // Add weight button
                    Button(action: {
                        showEditWeightSheet = true
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.purple)
                            .font(.system(size: 18))
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                Spacer()
                
                // Date with chevron pushed to the right
                if let weightDate = weightDate {
                    HStack(spacing: 4) {
                        Text(formatWeightLogDate(weightDate))
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // Bottom row: Weight value on left, chart on right
            HStack {
                // Left side - Weight value
                VStack(alignment: .leading, spacing: 4) {
                    if isLoadingWeight {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else if let weightLbs = currentWeightLbs {
                        HStack(alignment: .firstTextBaseline, spacing: 0) {
                            Text("\(Int(weightLbs.rounded()))")
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
                    
                    // Prompt for no data case
                    if currentWeightLbs == nil && !isLoadingWeight {
                        Text("Add your first weight entry")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Right side - Chart below the date
                if recentWeightLogs.count >= 2 {
                    weightTrendChart
                }
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
        
        // Calculate X-axis domain dynamically based on actual data points
        let spacing: Double = 0.8  // Good balance - visible lines but compact chart
        let maxXValue = Double(chartData.count - 1) * spacing
        let xAxisMin: Double = -0.5  // Small negative padding on left
        let xAxisMax: Double = maxXValue + 0.5  // Small padding on right
        
        return Chart {
            ForEach(chartData, id: \.offset) { index, log in
                let xValue = Double(index) * spacing  // Use consistent spacing
                
                LineMark(
                    x: .value("Day", xValue),
                    y: .value("Weight", log.weightKg * 2.20462)
                )
                .lineStyle(StrokeStyle(lineWidth: 2))
                .foregroundStyle(Color.purple)
                
                // Mask the line so it doesn't show through the hollow point
                PointMark(
                    x: .value("Day", xValue),
                    y: .value("Weight", log.weightKg * 2.20462)
                )
                .symbol(.circle)
                .symbolSize(CGSize(width: 10, height: 10))        // larger background
                .foregroundStyle(Color("iosfit"))  // same as card background

                // Outlined hollow point
                PointMark(
                    x: .value("Day", xValue),
                    y: .value("Weight", log.weightKg * 2.20462)
                )
                .symbol(.circle.strokeBorder(lineWidth: 2))
                .symbolSize(CGSize(width: 8, height: 8))
                .foregroundStyle(Color.purple)
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartXScale(domain: xAxisMin...xAxisMax) // Dynamic domain that fits all points perfectly
        .chartYScale(domain: yAxisMin...yAxisMax) // Custom scale to show variation
        .chartLegend(.hidden)
        .frame(width: 100, height: 40) // Proper size for good line visibility
        .background(Color.clear)
        .onAppear {
            print("🏋️ Chart Data Debug:")
            print("  - Chart data count: \(chartData.count)")
            print("  - Weight range: \(minWeight) to \(maxWeight) lbs")
            print("  - Y-axis scale: \(yAxisMin) to \(yAxisMax)")
            print("  - X-axis scale: \(xAxisMin) to \(xAxisMax)")
            for (index, log) in chartData {
                let weightLbs = log.weightKg * 2.20462
                print("  - Chart point \(index): \(weightLbs)lbs from \(log.dateLogged)")
            }
        }
    }
    
    // MARK: - Helper Functions
    
    private func formatWeightLogDate(_ dateString: String) -> String {
        // Try ISO8601DateFormatter first
        let iso8601Formatter = ISO8601DateFormatter()
        if let date = iso8601Formatter.date(from: dateString) {
            return formatParsedDate(date)
        }
        
        // Try various DateFormatter patterns
        let dateFormatters: [DateFormatter] = [
            {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSSXXXXX"
                return formatter
            }(),
            {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSXXXXX"
                return formatter
            }(),
            {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssXXXXX"
                return formatter
            }()
        ]
        
        for formatter in dateFormatters {
            if let date = formatter.date(from: dateString) {
                return formatParsedDate(date)
            }
        }
        
        print("❌ Failed to parse date: \(dateString)")
        return "Unknown date"
    }
    
    private func formatParsedDate(_ date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()
        
        let result: String
        if calendar.isDateInToday(date) {
            // Today: show time like "4:19 AM"
            let timeFormatter = DateFormatter()
            timeFormatter.dateFormat = "h:mm a"
            result = timeFormatter.string(from: date)
        } else if calendar.isDateInYesterday(date) {
            // Yesterday: show "Yesterday"
            result = "Yesterday"
        } else {
            // Other dates: show "Jun 4" format
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "MMM d"
            result = dateFormatter.string(from: date)
        }
        
        print("📅 Date formatting: \(date) -> '\(result)'")
        return result
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
        
        // Store vm.weight as the preferred source of truth
        let vmWeightLbs = vm.weight > 0 ? vm.weight * 2.20462 : nil
        
        // If vm has weight, use it immediately but still fetch logs for chart
        if let vmWeight = vmWeightLbs {
            currentWeightLbs = vmWeight
            print("🏋️ Got initial weight from DayLogsViewModel: \(vm.weight)kg = \(vmWeight)lbs")
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
                        let apiWeightLbs = mostRecentLog.weightKg * 2.20462
                        self.weightDate = mostRecentLog.dateLogged
                        
                        // Only update currentWeightLbs if vm.weight doesn't exist or API has newer data
                        if vmWeightLbs == nil {
                            self.currentWeightLbs = apiWeightLbs
                            print("🏋️ Got weight from API (no vm.weight): \(mostRecentLog.weightKg)kg = \(apiWeightLbs)lbs")
                        } else {
                            // Keep vm.weight as it's likely more recent (just saved)
                            print("🏋️ Keeping vm.weight (\(vmWeightLbs!)lbs) over API weight (\(apiWeightLbs)lbs)")
                        }
                    } else {
                        print("🏋️ No weight logs found")
                        if vmWeightLbs == nil {
                            self.currentWeightLbs = nil
                        }
                        self.weightDate = nil
                    }
                case .failure(let error):
                    print("❌ Error fetching weight logs: \(error)")
                    if vmWeightLbs == nil {
                        self.currentWeightLbs = nil
                        self.weightDate = nil
                    }
                    self.recentWeightLogs = []
                }
            }
        }
    }
}



// MARK: - BMI Gauge (upright semicircle, self‑centering)



struct ArcOne: View {
    var body: some View {
        ZStack {
            // The semicircle arc with gradient
            SemicircleArc()
                .stroke(
                    LinearGradient(
                        stops: [
                            Gradient.Stop(color: Color.blue, location: 0.00),
                            Gradient.Stop(color: Color.blue, location: 0.25),
                            Gradient.Stop(color: Color(red: 0.2, green: 0.78, blue: 0.35), location: 0.35),
                            Gradient.Stop(color: Color(red: 0.2, green: 0.78, blue: 0.35), location: 0.65),
                            Gradient.Stop(color: Color(red: 1, green: 0.23, blue: 0.19), location: 0.75),
                            Gradient.Stop(color: Color(red: 1, green: 0.23, blue: 0.19), location: 1.00),
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    lineWidth: 8
                )

                 CircularTextView(title: "           Underweight             Normal                Overweight", radius: 230)
                    .offset(y: 65) 

            // BMI value in center
            VStack(spacing: 4) {
                Text("BMI")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text("23.2")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.green)

            }
            .offset(y: 85) // Positioned in the center of the arc

      
        }
        .frame(width: 365, height: 215)
        .padding(.vertical, 20)
    }
}

// Custom shape for semicircle arc
struct SemicircleArc: Shape {
    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.maxY)
        let radius = min(rect.width, rect.height) / 2 - 4  // Adjusted for thinner stroke
        
        var path = Path()
        path.addArc(
            center: center,
            radius: radius,
            startAngle: .degrees(180), // Start from left (180°)
            endAngle: .degrees(0),     // End at right (0°)
            clockwise: false           // Draw counter-clockwise for top semicircle
        )
        return path
    }
}

// Custom view for text that follows a curved path
struct CurvedText: View {
    let text: String
    let radius: CGFloat
    let centerAngle: Double // Center angle in degrees
    let center: CGPoint
    
    var body: some View {
        ZStack {
            ForEach(Array(text.enumerated()), id: \.offset) { index, character in
                let charAngle = calculateCharacterAngle(for: index)
                let x = center.x + cos(charAngle * .pi / 180) * radius
                let y = center.y - sin(charAngle * .pi / 180) * radius
                
                Text(String(character))
                    .font(.subheadline.weight(.medium))
                    .rotationEffect(.degrees((charAngle - 90) * 0.1)) // VERY minimal rotation
                    .position(x: x, y: y)
            }
        }
    }
    
    private func calculateCharacterAngle(for index: Int) -> Double {
        let textLength = Double(text.count)
        let characterSpacing = 2.0 // Very tight spacing for subtle curve
        let totalSpread = characterSpacing * (textLength - 1)
        let startAngle = centerAngle + totalSpread / 2
        return startAngle - Double(index) * characterSpacing
    }
}



/// One coloured slice of the top semicircle.
private struct GaugeSlice: View {
    var colour: Color
    var startDeg: Double  // e.g. 180
    var endDeg:   Double  // e.g. 135
    var lineWidth: CGFloat

    var body: some View {
        GaugeArc(startDeg: startDeg, endDeg: endDeg)
            .stroke(colour,
                    style: StrokeStyle(lineWidth: lineWidth,
                                       lineCap: .butt))
    }
}

 /// The arc path centred at the *bottom* of the view so only the top half shows.
 private struct GaugeArc: Shape {
     var startDeg: Double
     var endDeg:   Double

     func path(in rect: CGRect) -> Path {
         let centre = CGPoint(x: rect.midX, y: rect.maxY)
         let radius = min(rect.width, rect.height) / 2 - 10  // keep stroke inside
         var p = Path()
         p.addArc(center: centre,
                  radius: radius,
                  startAngle: .degrees(startDeg),
                  endAngle: .degrees(endDeg),
                  clockwise: false)  // Changed to counter-clockwise for proper arc direction
         return p
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




struct CircularTextView: View {
    @State var letterWidths: [Int: Double] = [:]
    @State var title: String
 
    var lettersOffset: [(offset: Int, element: Character)] {
        return Array(title.enumerated())
    }
    var radius: Double
 
    var body: some View {
        ZStack {
            ForEach(lettersOffset, id: \.offset) { index, letter in
                VStack {
                    Text(String(letter))
                        .font(.system(size: 13, design: .monospaced))
                        .kerning(5)
                        .onGeometryChange(for: Double.self) { proxy in
                            proxy.size.width
                        } action: { width in
                            letterWidths[index] = width
                        }
                    Spacer()
                }
                .rotationEffect(fetchAngle(at: index))
            }
        }
        .frame(width: 200, height: 200)
        .rotationEffect(.degrees(214))
    }
 
    func fetchAngle(at letterPosition: Int) -> Angle {
        let times2pi: (Double) -> Double = { $0 * 2 * .pi }
        let circumference = times2pi(radius)
        let finalAngle = times2pi(letterWidths.filter { $0.key <= letterPosition }.map(\.value).reduce(0, +) / circumference)
        return .radians(finalAngle)
    }
}

#Preview {
    MyProfileView(isAuthenticated: .constant(true))
}

