//
//  UserGoals.swift
//  Pods
//
//  Created by Dimi Nunez on 2/11/25.
//

import Foundation
import SwiftUI

struct DailyGoals: Codable {
    var calories: Int
    var protein: Int
    var carbs: Int
    var fat: Int
    
    static let `default` = DailyGoals(
        calories: 2000,
        protein: 150,
        carbs: 250,
        fat: 65
    )
}

class UserGoalsManager {
    static let shared = UserGoalsManager()
    private let defaults = UserDefaults.standard
    private let goalsKey = "userDailyGoals"
    
    private init() {}
    
    var dailyGoals: DailyGoals {
        get {
            guard let data = defaults.data(forKey: goalsKey),
                  let goals = try? JSONDecoder().decode(DailyGoals.self, from: data) else {
                return DailyGoals.default
            }
            return goals
        }
        set {
            if let encoded = try? JSONEncoder().encode(newValue) {
                defaults.set(encoded, forKey: goalsKey)
            }
        }
    }
}


struct GoalProgressBar: View {
    let label: String
    let value: Double
    let goal: Double
    let unit: String
    let color: Color
    let percentage: Double
    
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(label)
                Spacer()
                Text(String(format: "%.1f/%.0f%@", value, goal, unit))
                    .foregroundColor(.secondary)
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 8)
                        .cornerRadius(4)
                    
                    Rectangle()
                        .fill(color)
                        .frame(width: min(CGFloat(percentage) / 100 * geometry.size.width, geometry.size.width), height: 8)
                        .cornerRadius(4)
                }
            }
            .frame(height: 8)
            
            Text(String(format: "%.0f%%", percentage))
                .font(.caption)
                .foregroundColor(color)
        }
    }
}