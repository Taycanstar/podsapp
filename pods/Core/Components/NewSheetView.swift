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
    @Environment(\.colorScheme) private var colorScheme

    let options = [
        ("Search", "magnifyingglass"),
        ("Voice Log", "mic"),
        ("Scan Food", "barcode.viewfinder"),
        ("Saved Meals", "bookmark"),
        ("Workout", "dumbbell")
    ]

    var body: some View {
        VStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 2.5)
                .frame(width: 36, height: 2)
                .foregroundColor(Color("grabber"))
                .padding(.top, 12)
                .padding(.bottom, 24)

            // Grid layout
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 20),
                GridItem(.flexible(), spacing: 20),
                GridItem(.flexible(), spacing: 20)
            ], spacing: 32) {
                ForEach(options, id: \.0) { option in
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(circleBackgroundColor)
                                .frame(width: 70, height: 70)

                            Image(systemName: option.1)
                                .font(.system(size: 28, weight: .medium))
                                .foregroundColor(circleIconColor)
                        }

                        Text(option.0)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.center)
                    }
                    .onTapGesture {
                        // Handle tap
                        switch option.0 {
                          case "Food":
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
                          case "Saved Meals":
                            HapticFeedback.generate()
                            isPresented = false
                            viewModel.showFoodContainer(selectedMeal: selectedMeal, initialTab: "savedMeals")
                          case "Workout":
                            HapticFeedback.generate()
                            isPresented = false
                            showLogWorkoutView = true
                          default:
                              break
                          }
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)

            Spacer()
        }
        .padding(.horizontal, 0)
        .background(
            RoundedRectangle(cornerRadius: 25)
                .foregroundColor(Color("sheetbg"))
                .ignoresSafeArea()
        )
    }
}

private extension NewSheetView {
    var circleBackgroundColor: Color {
        if colorScheme == .dark {
            return Color.black.opacity(0.5)
        }

        return Color(red: 222.0 / 255.0, green: 222.0 / 255.0, blue: 222.0 / 255.0)
    }

    var circleIconColor: Color {
        colorScheme == .dark ? .white : .primary
    }
}
