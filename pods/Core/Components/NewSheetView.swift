//
//  NewSheetView.swift
//  Pods
//
//  Created by Dimi Nunez on 2/1/25.
//

import SwiftUI
import AVFoundation


struct NewSheetView: View {
    @Binding var isPresented: Bool
    @Binding var showingVideoCreationScreen: Bool
    @Binding var showQuickPodView: Bool
    @Binding var selectedTab: Int 
    @Binding var showFoodScanner: Bool
    @Binding var showVoiceLog: Bool
    @Binding var showLogWorkoutView: Bool
    @Binding var selectedMeal: String
    @EnvironmentObject var viewModel: OnboardingViewModel

    let options = [
        ("Log Food", "magnifyingglass"),
        ("Voice Log", "mic"),
        ("Scan Food", "barcode.viewfinder"),
        // ("Log Workout", "dumbbell")
    ]

    var body: some View {
        VStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 2.5)
                .frame(width: 36, height: 2)
                .foregroundColor(Color("grabber"))
                .padding(.top, 12)
            
            Menu {
                     
                Button("Snacks") { 
                    selectedMeal = "Snacks"
                    print("🍽️ NewSheetView: Selected meal changed to: \(selectedMeal)")
                }
                 Button("Dinner") { 
                    selectedMeal = "Dinner"
                    print("🍽️ NewSheetView: Selected meal changed to: \(selectedMeal)")
                }
                        Button("Lunch") { 
                    selectedMeal = "Lunch"
                    print("🍽️ NewSheetView: Selected meal changed to: \(selectedMeal)")
                }
          
                Button("Breakfast") { 
                    selectedMeal = "Breakfast"
                    print("🍽️ NewSheetView: Selected meal changed to: \(selectedMeal)")
                }
         
            } label: {
                HStack(spacing: 4) {
                    Text(selectedMeal)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.top, 24)
            .padding(.bottom, 8)
            
            Divider()
            
            ForEach(options, id: \.0) { option in
                HStack(spacing: 0) {
                    HStack(spacing: 12) {
                        Image(systemName: option.1)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.primary)
                            .frame(width: 30)
                            .padding(.leading)
                        
                        Text(option.0)
                            .font(.system(size: 15))
                            .padding(.vertical, 16)
                            .foregroundColor(.primary)
                    }
                    Spacer()
                }
                .background(Color(.systemBackground))
                .onTapGesture {
                    // Handle tap
                    switch option.0 {
                      case "Pod":
                          isPresented = false  
                          showQuickPodView = true
                      case "Log Food":
                        HapticFeedback.generate()
                        isPresented = false
                        viewModel.showFoodContainer(selectedMeal: selectedMeal)
                      case "Voice Log":
                        HapticFeedback.generate()
                        print("🍽️ NewSheetView: Tapping Voice Log with selectedMeal: \(selectedMeal)")
                        isPresented = false
                        showVoiceLog = true
                      case "Scan Food":
                        HapticFeedback.generate()
                        isPresented = false
                        showFoodScanner = true
                      case "Log Workout":
                        HapticFeedback.generate()
                        isPresented = false
                        showLogWorkoutView = true
                      default:
                          break
                      }
                }
                
                if option.0 != options.last?.0 {
                    Divider()
                        .frame(height: 0.5)
                        .padding(.leading, 65)
                        .opacity(0.5)
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 0)
        .background(
            RoundedRectangle(cornerRadius: 25)
                .foregroundColor(Color(.systemBackground))
                .ignoresSafeArea()
        )
    }
}
