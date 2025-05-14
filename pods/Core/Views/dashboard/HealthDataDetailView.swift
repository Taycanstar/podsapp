import SwiftUI
import HealthKit
import Charts

struct HealthDataDetailView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel = HealthKitViewModel()
    
    let dailyStepGoal: Double = 10000
    let dailyWaterGoal: Double = 2.5 // liters
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Activity metrics section
                    sectionHeader(title: "Activity", icon: "figure.walk")
                    
                    VStack(spacing: 16) {
                        // Steps card
                        metricCard(
                            title: "Steps",
                            value: "\(Int(viewModel.stepCount))",
                            icon: "figure.walk",
                            color: .green,
                            progress: min(viewModel.stepCount / dailyStepGoal, 1.0),
                            goal: "\(Int(dailyStepGoal))"
                        )
                        
                        // Calories card
                        metricCard(
                            title: "Active Calories",
                            value: "\(Int(viewModel.activeEnergy))",
                            icon: "flame.fill",
                            color: Color("brightOrange"),
                            progress: min(viewModel.activeEnergy / 400, 1.0),
                            goal: "400"
                        )
                    }
                    .padding(.horizontal)
                    
                    // Nutrition metrics section
                    sectionHeader(title: "Nutrition", icon: "fork.knife")
                    
                    VStack(spacing: 16) {
                        // Water intake card
                        metricCard(
                            title: "Water Intake",
                            value: String(format: "%.1f L", viewModel.waterIntake),
                            icon: "drop.fill",
                            color: .blue,
                            progress: min(viewModel.waterIntake / dailyWaterGoal, 1.0),
                            goal: "\(dailyWaterGoal) L"
                        )
                        
                        // Nutrition data preview if available
                        if !viewModel.nutritionData.isEmpty {
                            nutritionDataCard
                        }
                    }
                    .padding(.horizontal)
                    
                    // Recent workouts section if available
                    if !viewModel.recentWorkouts.isEmpty {
                        sectionHeader(title: "Recent Workouts", icon: "dumbbell.fill")
                        
                        VStack(spacing: 12) {
                            ForEach(viewModel.recentWorkouts.prefix(3), id: \.uuid) { workout in
                                workoutCard(workout: workout)
                            }
                            
                            if viewModel.recentWorkouts.count > 3 {
                                Button(action: {
                                    // Navigate to all workouts view (could be implemented in future)
                                }) {
                                    Text("View All Workouts")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.accentColor)
                                        .padding()
                                        .frame(maxWidth: .infinity)
                                        .background(Color("iosnp"))
                                        .cornerRadius(12)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    // Status message
                    if viewModel.isLoading {
                        ProgressView()
                            .padding()
                    }
                    
                    Spacer(minLength: 50)
                }
                .padding(.top)
            }
            .background(Color("iosbg2").ignoresSafeArea())
            .navigationTitle("Health Data")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.primary)
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        viewModel.reloadHealthData()
                    }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.primary)
                    }
                }
            }
            .onAppear {
                viewModel.reloadHealthData()
            }
        }
    }
    
    // Nutrition data card
    private var nutritionDataCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Today's Nutrition")
                .font(.system(size: 18, weight: .bold))
            
            VStack(spacing: 12) {
                nutritionRow(
                    name: "Calories",
                    value: viewModel.nutritionData[.dietaryEnergyConsumed] ?? 0,
                    unit: "kcal",
                    color: Color("brightOrange")
                )
                
                nutritionRow(
                    name: "Protein",
                    value: viewModel.nutritionData[.dietaryProtein] ?? 0,
                    unit: "g",
                    color: .blue
                )
                
                nutritionRow(
                    name: "Carbs",
                    value: viewModel.nutritionData[.dietaryCarbohydrates] ?? 0,
                    unit: "g",
                    color: Color("darkYellow")
                )
                
                nutritionRow(
                    name: "Fat",
                    value: viewModel.nutritionData[.dietaryFatTotal] ?? 0,
                    unit: "g",
                    color: .pink
                )
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color("iosnp"))
        .cornerRadius(12)
    }
    
    // Section header view
    private func sectionHeader(title: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.accentColor)
            
            Text(title)
                .font(.system(size: 20, weight: .bold))
            
            Spacer()
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }
    
    // Metric card view
    private func metricCard(title: String, value: String, icon: String, color: Color, progress: Double, goal: String) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(color)
                
                Text(title)
                    .font(.system(size: 18, weight: .bold))
                
                Spacer()
                
                Text(value)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(color)
            }
            
            VStack(spacing: 4) {
                // Progress bar
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.secondary.opacity(0.2))
                        .frame(height: 8)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color)
                        .frame(width: UIScreen.main.bounds.width * 0.8 * progress, height: 8)
                }
                
                HStack {
                    Text("0")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("Goal: \(goal)")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color("iosnp"))
        .cornerRadius(12)
    }
    
    // Nutrition row view
    private func nutritionRow(name: String, value: Double, unit: String, color: Color) -> some View {
        HStack {
            Text(name)
                .font(.system(size: 16, weight: .medium))
            
            Spacer()
            
            Text("\(Int(value)) \(unit)")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(color)
        }
    }
    
    // Workout card view
    private func workoutCard(workout: HKWorkout) -> some View {
        HStack(spacing: 16) {
            // Workout type icon
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.2))
                    .frame(width: 50, height: 50)
                
                Image(systemName: iconForWorkoutType(workout.workoutActivityType))
                    .font(.system(size: 20))
                    .foregroundColor(.blue)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(nameForWorkoutType(workout.workoutActivityType))
                    .font(.system(size: 16, weight: .bold))
                
                HStack(spacing: 12) {
                    Label(
                        formatDuration(workout.duration),
                        systemImage: "clock"
                    )
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    
                    if let energyBurned = workout.totalEnergyBurned {
                        Label(
                            "\(Int(energyBurned.doubleValue(for: .kilocalorie()))) kcal",
                            systemImage: "flame"
                        )
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            // Date
            Text(formatDate(workout.startDate))
                .font(.system(size: 14))
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color("iosnp"))
        .cornerRadius(12)
    }
    
    // Helper function to get an icon for workout type
    private func iconForWorkoutType(_ type: HKWorkoutActivityType) -> String {
        switch type {
        case .running:
            return "figure.run"
        case .cycling:
            return "figure.outdoor.cycle"
        case .walking:
            return "figure.walk"
        case .swimming:
            return "figure.pool.swim"
        case .hiking:
            return "figure.hiking"
        case .yoga:
            return "figure.mind.and.body"
        case .functionalStrengthTraining:
            return "dumbbell"
        default:
            return "figure.strengthtraining.traditional"
        }
    }
    
    // Helper function to get a name for workout type
    private func nameForWorkoutType(_ type: HKWorkoutActivityType) -> String {
        switch type {
        case .running:
            return "Running"
        case .cycling:
            return "Cycling"
        case .walking:
            return "Walking"
        case .swimming:
            return "Swimming"
        case .hiking:
            return "Hiking"
        case .yoga:
            return "Yoga"
        case .functionalStrengthTraining:
            return "Strength Training"
        default:
            return "Workout"
        }
    }
    
    // Helper function to format workout duration
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes) min"
        }
    }
    
    // Helper function to format date
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
}

struct HealthDataDetailView_Previews: PreviewProvider {
    static var previews: some View {
        HealthDataDetailView()
    }
} 
