//
//  MuscleRecoveryCompactView.swift
//  pods
//
//  Created by Dimi Nunez on 7/16/25.
//

//
//  MuscleRecoveryCompactView.swift
//  pods
//
//  Created by Dimi Nunez on 7/16/25.
//

import SwiftUI

struct MuscleRecoveryCompactView: View {
    @State private var recoveryData: [MuscleRecoveryService.MuscleRecoveryData] = []
    @State private var showingFullView = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Muscle Recovery")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button("View All") {
                    showingFullView = true
                }
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.accentColor)
            }
            
            // Show top 4 main muscle groups
            let mainMuscles = recoveryData.filter { $0.muscleGroup.isMainMuscleGroup }.prefix(4)
            
            if !mainMuscles.isEmpty {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 2), spacing: 8) {
                    ForEach(Array(mainMuscles), id: \.muscleGroup) { muscle in
                        CompactMuscleCard(muscleData: muscle)
                    }
                }
            } else {
                Text("Complete a workout to see recovery data")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            }
        }
        .padding()
        .background(Color("iosnp"))
        .cornerRadius(12)
        .onAppear {
            loadRecoveryData()
        }
        .sheet(isPresented: $showingFullView) {
            MuscleRecoveryView()
        }
    }
    
    private func loadRecoveryData() {
        recoveryData = MuscleRecoveryService.shared.getMuscleRecoveryData()
    }
}

struct CompactMuscleCard: View {
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
    
    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(muscleData.muscleGroup.displayName)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                Text("\(Int(muscleData.recoveryPercentage))%")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(recoveryColor)
            }
            
            Spacer()
            
            // Mini progress circle
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 2)
                    .frame(width: 16, height: 16)
                
                Circle()
                    .trim(from: 0, to: muscleData.recoveryPercentage / 100.0)
                    .stroke(recoveryColor, lineWidth: 2)
                    .frame(width: 16, height: 16)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.3), value: muscleData.recoveryPercentage)
            }
        }
        .padding(8)
        .background(Color("iosbg"))
        .cornerRadius(8)
    }
}

#Preview {
    MuscleRecoveryCompactView()
        .padding()
} 