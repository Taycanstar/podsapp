//
//  MuscleRecoveryView.swift
//  pods
//
//  Created by Dimi Nunez on 7/16/25.
//

//
//  MuscleRecoveryView.swift
//  Pods
//
//  Created by Assistant on 12/21/24.
//

import SwiftUI

struct MuscleRecoveryView: View {
    @StateObject private var recoveryService = MuscleRecoveryService.shared
    @State private var recoveryData: [MuscleRecoveryService.MuscleRecoveryData] = []
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Muscle Recovery")
                        .font(.title2)
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Text("Track your muscle recovery to optimize training")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal)
                .padding(.top, 20)
                .padding(.bottom, 16)
                
                // Recovery grid
                ScrollView {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2), spacing: 16) {
                        ForEach(recoveryData, id: \.muscleGroup) { muscle in
                            MuscleRecoveryCard(muscleData: muscle)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 100) // Space for tab bar
                }
            }
            .background(Color("iosbg"))
            .navigationBarHidden(true)
        }
        .onAppear {
            loadRecoveryData()
        }
    }
    
    private func loadRecoveryData() {
        recoveryData = MuscleRecoveryService.shared.getMuscleRecoveryData()
    }
}

struct MuscleRecoveryCard: View {
    let muscleData: MuscleRecoveryService.MuscleRecoveryData
    
    private var recoveryColor: Color {
        switch muscleData.recoveryPercentage {
        case 0..<60:
            return .red
        case 60..<85:
            return .orange
        case 85..<100:
            return .yellow
        default:
            return .green
        }
    }
    
    private var recoveryStatusText: String {
        switch muscleData.recoveryPercentage {
        case 0..<60:
            return "Recovering"
        case 60..<85:
            return "Partial"
        case 85..<100:
            return "Ready"
        default:
            return "Rested"
        }
    }
    
    private var timeUntilRecovered: String {
        let now = Date()
        let timeRemaining = muscleData.estimatedFullRecoveryDate.timeIntervalSince(now)
        
        if timeRemaining <= 0 {
            return "Fully rested"
        }
        
        let hours = Int(timeRemaining / 3600)
        if hours < 24 {
            return "\(hours)h remaining"
        } else {
            let days = hours / 24
            let remainingHours = hours % 24
            if remainingHours == 0 {
                return "\(days)d remaining"
            } else {
                return "\(days)d \(remainingHours)h remaining"
            }
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with muscle name and recovery percentage
            VStack(alignment: .leading, spacing: 4) {
                Text(muscleData.muscleGroup.displayName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text(recoveryStatusText)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(recoveryColor)
            }
            
            // Recovery progress bar
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("\(Int(muscleData.recoveryPercentage))%")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    // Ready indicator
                    if muscleData.isRecommendedForTraining {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.green)
                    }
                }
                
                // Progress bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // Background bar
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 6)
                        
                        // Progress bar
                        RoundedRectangle(cornerRadius: 4)
                            .fill(recoveryColor)
                            .frame(
                                width: geometry.size.width * (muscleData.recoveryPercentage / 100.0),
                                height: 6
                            )
                            .animation(.easeInOut(duration: 0.3), value: muscleData.recoveryPercentage)
                    }
                }
                .frame(height: 6)
            }
            
            // Time information
            VStack(alignment: .leading, spacing: 2) {
                if muscleData.lastWorkedDate != Date.distantPast {
                    Text("Last trained: \(formatLastWorkoutDate())")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                
                if muscleData.recoveryPercentage < 100 {
                    Text(timeUntilRecovered)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(16)
        .background(Color("iosnp"))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(recoveryColor.opacity(0.3), lineWidth: 1)
        )
    }
    
    private func formatLastWorkoutDate() -> String {
        let calendar = Calendar.current
        let now = Date()
        
        if calendar.isDateInToday(muscleData.lastWorkedDate) {
            return "Today"
        } else if calendar.isDateInYesterday(muscleData.lastWorkedDate) {
            return "Yesterday"
        } else {
            let daysAgo = calendar.dateComponents([.day], from: muscleData.lastWorkedDate, to: now).day ?? 0
            if daysAgo <= 7 {
                return "\(daysAgo)d ago"
            } else {
                let formatter = DateFormatter()
                formatter.dateFormat = "MMM d"
                return formatter.string(from: muscleData.lastWorkedDate)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    MuscleRecoveryView()
} 