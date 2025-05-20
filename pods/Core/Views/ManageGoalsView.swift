//
//  ManageGoalsView.swift
//  Pods
//
//  Created by Dimi Nunez on 5/19/25.
//

import SwiftUI

struct ManageGoalsView: View {
    @EnvironmentObject var vm: DayLogsViewModel
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        List {
            Section(header: Text("Weight Management")) {
                NavigationLink(destination: UpdateWeight()) {
                    HStack {
                            Label("Current Weight", systemImage: "scalemass").foregroundColor(.primary)
                        Spacer()
                        if vm.weight > 0 {
                            let weightInLbs = Int(vm.weight * 2.20462)
                            Text("\(weightInLbs) lbs")
                                .foregroundColor(.secondary)
                        } else {
                            Text("Set weight")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                NavigationLink(destination: UpdateDesiredWeight()) {
                    HStack {
                        Label("Weight Goal", systemImage: "chart.line.uptrend.xyaxis").foregroundColor(.primary)
                        Spacer()
                        if vm.desiredWeightLbs > 0 {
                            Text("\(Int(vm.desiredWeightLbs)) lbs")
                                .foregroundColor(.secondary)
                        } else if let goalWeight = UserDefaults.standard.value(forKey: "weightGoalPounds") as? Double {
                            Text("\(Int(goalWeight)) lbs")
                                .foregroundColor(.secondary)
                        } else {
                            Text("Set goal")
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            
            Section(header: Text("Nutrition Goals")) {
                NavigationLink(destination: GoalProgress()) {
                    HStack {
                        Label("Daily Nutrition", systemImage: "fork.knife").foregroundColor(.primary)
                        Spacer()
                        Text("\(Int(vm.calorieGoal)) cals")
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .navigationBarTitle("Goals & Weight", displayMode: .inline)
    }
}

#Preview {
    NavigationView {
        ManageGoalsView()
            .environmentObject(DayLogsViewModel())
    }
}
