//
//  DobView.swift
//  Pods
//
//  Created by Dimi Nunez on 6/7/25.
//

import SwiftUI

struct DobView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    @State private var navigateToNextStep = false
    
    // Date of birth components
    @State private var selectedMonth = 0
    @State private var selectedDay = 1
    @State private var selectedYear = Calendar.current.component(.year, from: Date()) - 30
    
    // Available ranges and options
    let months = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]
    let days = Array(1...31)
    
    // Calculate year range - from 100 years ago to current year
    var yearRange: [Int] {
        let currentYear = Calendar.current.component(.year, from: Date())
        return Array((currentYear-100)...currentYear)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Navigation and progress bar
            VStack(spacing: 16) {
                HStack {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.primary)
                    }
                    Spacer()
                }
                .padding(.horizontal)
                
                // Progress bar - 4/5 completed (80%)
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.secondary.opacity(0.3))
                        .frame(height: 4)
                        .cornerRadius(2)
                    
                    Rectangle()
                        .fill(Color.primary)
                        .frame(width: UIScreen.main.bounds.width * OnboardingProgress.progressFor(screen: .dob), height: 4)
                        .cornerRadius(2)
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
            
            // Title and instructions
            VStack(alignment: .leading, spacing: 12) {
                Text("When were you born?")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.primary)
                
                Text("We'll use this to tailor your personalized plan.")
                    .font(.system(size: 18))
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)
            .padding(.bottom, 40)
            
            Spacer()
            
            // Date of birth pickers
            HStack(spacing: 10) {
                // Month picker
                DateScrollPicker(
                    selection: $selectedMonth,
                    options: months,
                    label: ""
                )
                .frame(maxWidth: .infinity)
                .frame(height: 200)
                
                // Day picker
                DateScrollPicker(
                    selection: $selectedDay,
                    options: days.map { String($0) },
                    label: ""
                )
                .frame(width: 100, height: 200)
                
                // Year picker
                DateScrollPicker(
                    selection: Binding(
                        get: { self.yearRange.firstIndex(of: self.selectedYear) ?? 0 },
                        set: { self.selectedYear = self.yearRange[$0] }
                    ),
                    options: yearRange.map { String($0) },
                    label: ""
                )
                .frame(maxWidth: .infinity)
                .frame(height: 200)
            }
            .padding(.horizontal)
            
            Spacer()
            
            // Continue button
            VStack {
                NavigationLink(destination: DesiredWeightView(), isActive: $navigateToNextStep) {
                    Button(action: {
                        HapticFeedback.generate()
                        saveDateOfBirth()
                        navigateToNextStep = true
                    }) {
                        Text("Continue")
                            .font(.system(size: 18, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Color.accentColor)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 16)
            }
            .padding(.bottom, 24)
            .background(Material.ultraThin)
        }
        .background(Color(UIColor.systemBackground))
        .edgesIgnoringSafeArea(.bottom)
        .navigationBarHidden(true)
        .background(
            NavigationLink(
                destination: DesiredWeightView(),
                isActive: $navigateToNextStep
            ) {
                EmptyView()
            }
        )
        .onAppear {
            // Save current step to UserDefaults when this view appears
            UserDefaults.standard.set("DobView", forKey: "currentOnboardingStep")
            UserDefaults.standard.set(3, forKey: "onboardingFlowStep") // Raw value for this step
            UserDefaults.standard.set(true, forKey: "onboardingInProgress")
            UserDefaults.standard.synchronize()
            print("📱 DobView appeared - saved current step")
        }
    }
    
    private func saveDateOfBirth() {
        // Create date components from selections
        var dateComponents = DateComponents()
        dateComponents.year = selectedYear
        dateComponents.month = selectedMonth + 1 // Months are 1-indexed
        dateComponents.day = selectedDay
        
        // Create date from components
        if let date = Calendar.current.date(from: dateComponents) {
            // Format date as YYYY-MM-DD
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            let dateString = formatter.string(from: date)
            
            // Save date string
            UserDefaults.standard.set(dateString, forKey: "dateOfBirth")
            
            // Save individual components for easier access
            UserDefaults.standard.set(selectedMonth, forKey: "birthMonth")
            UserDefaults.standard.set(selectedDay, forKey: "birthDay")
            UserDefaults.standard.set(selectedYear, forKey: "birthYear")
            
            // Calculate age
            let now = Date()
            let ageComponents = Calendar.current.dateComponents([.year], from: date, to: now)
            if let age = ageComponents.year {
                UserDefaults.standard.set(age, forKey: "age")
            }
        }
    }
}

// Custom scroll wheel picker component for date selection
struct DateScrollPicker: View {
    @Binding var selection: Int
    let options: [String]
    let label: String
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack {
            if !label.isEmpty {
                Text(label)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.secondary)
                    .padding(.bottom, 4)
            }
            
            Picker("", selection: $selection) {
                ForEach(0..<options.count, id: \.self) { index in
                    Text(options[index])
                        .font(.system(size: 18))
                        .tag(index)
                }
            }
            .pickerStyle(WheelPickerStyle())
            .frame(height: 150)
            .clipped()
            .onChange(of: selection) { _ in
                HapticFeedback.generateLigth()
            }
        }
        .background(colorScheme == .dark ? Color(UIColor.systemGray6) : Color(UIColor.systemGray6))
        .cornerRadius(12)
    }
}

#Preview {
    DobView()
}
