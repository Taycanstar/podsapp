import SwiftUI
import HealthKit

struct HealthDataCard: View {
    @StateObject private var viewModel = HealthKitViewModel()
    @State private var showHealthDetail = false
    @State private var showPermissionAlert = false
    
    // Date to display health data for
    var date: Date?
    
    let dailyStepGoal: Double = 10000 // Default step goal
    let dailyWaterGoal: Double = 2.5 // Default water goal in liters
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Health Data")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if viewModel.isLoading {
                    ProgressView()
                        .scaleEffect(0.7)
                }
            }
            .padding(.horizontal)
            .padding(.top, 12)
            
            if let error = viewModel.error {
                errorView(message: error.localizedDescription)
            } else if !viewModel.isAuthorized {
                unauthorizedView()
            } else if !HealthKitManager.shared.isHealthDataAvailable {
                errorView(message: "Health data not available on this device")
            } else {
                healthMetricsView
            }
        }
        .frame(height: 85) // Match the height of other cards
        .background(Color("iosnp"))
        .cornerRadius(12)
        .onAppear {
            // Use the provided date or default to today
            if let date = date {
                viewModel.reloadHealthData(for: date)
            } else {
            viewModel.reloadHealthData()
            }
        }
        .onChange(of: date) { newDate in
            // Update health data when the date changes
            if let newDate = newDate {
                viewModel.reloadHealthData(for: newDate)
            }
        }
        .onTapGesture {
            if !viewModel.isAuthorized && HealthKitManager.shared.isHealthDataAvailable {
                // Show permission alert if tapped and not authorized
                showPermissionAlert = true
            } else {
                // Otherwise show detail view
            showHealthDetail = true
            }
        }
        .sheet(isPresented: $showHealthDetail) {
            // Pass the current date to the detail view
            HealthDataDetailView(date: date ?? Date())
        }
        .alert("Health Permissions Required", isPresented: $showPermissionAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Allow Access") {
                viewModel.requestHealthKitPermissions()
            }
        } message: {
            Text("To display your health data, Pods needs access to Apple Health. Your data is kept private and never leaves your device.")
        }
    }
    
    // Customized unauthorized view with a button to request permissions
    private func unauthorizedView() -> some View {
        VStack(spacing: 6) {
            HStack {
                Image(systemName: "heart.text.square")
                    .font(.system(size: 18))
                    .foregroundColor(.accentColor)
                
                Text("Connect Apple Health")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.accentColor)
            }
            
            Text("Tap to sync your health and workout data")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 12)
        .contentShape(Rectangle()) // Make entire area tappable
        .onTapGesture {
            showPermissionAlert = true
        }
    }
    
    private var healthMetricsView: some View {
        HStack(spacing: 12) {
            // Steps metric
            metricView(
                icon: "figure.walk",
                value: "\(Int(viewModel.stepCount))",
                label: "Steps",
                progress: min(viewModel.stepCount / dailyStepGoal, 1.0),
                color: .green
            )
            
            Divider()
                .frame(height: 40)
            
            // Active calories metric
            metricView(
                icon: "flame.fill",
                value: "\(Int(viewModel.activeEnergy))",
                label: "Active Cal",
                progress: min(viewModel.activeEnergy / 400, 1.0), // Assuming 400 cals as a decent daily goal
                color: Color("brightOrange")
            )
            
            Divider()
                .frame(height: 40)
            
            // Water intake metric
            metricView(
                icon: "drop.fill",
                value: String(format: "%.1f L", viewModel.waterIntake),
                label: "Water",
                progress: min(viewModel.waterIntake / dailyWaterGoal, 1.0),
                color: .blue
            )
        }
        .padding(.horizontal)
        .padding(.bottom, 12)
    }
    
    private func metricView(icon: String, value: String, label: String, progress: Double, color: Color) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundColor(color)
                
                Text(value)
                    .font(.system(size: 16, weight: .bold))
            }
            
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
            
            // Progress bar
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.secondary.opacity(0.2))
                    .frame(height: 4)
                
                RoundedRectangle(cornerRadius: 2)
                    .fill(color)
                    .frame(width: 70 * progress, height: 4)
            }
            .frame(width: 70)
        }
        .frame(maxWidth: .infinity)
    }
    
    private func errorView(message: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 20))
                .foregroundColor(.orange)
            
            Text(message)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 12)
    }
}

struct HealthDataCard_Previews: PreviewProvider {
    static var previews: some View {
        HealthDataCard()
            .previewLayout(.sizeThatFits)
            .padding()
    }
} 
