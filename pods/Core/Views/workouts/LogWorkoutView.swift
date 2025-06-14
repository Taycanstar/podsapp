//
//  LogWorkoutView.swift
//  Pods
//
//  Created by Dimi Nunez on 6/5/25.
//

import SwiftUI

struct LogWorkoutView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedTab: Int
    @State private var searchText = ""
    @FocusState private var isSearchFieldFocused: Bool
    @State private var showCreateWorkout = false
    
    // Add WorkoutManager
    @StateObject private var workoutManager = WorkoutManager()
    
    // Add user email - you'll need to pass this in or get it from environment
    @State private var userEmail: String = UserDefaults.standard.string(forKey: "user_email") ?? ""
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Background color for the entire view
            Color("iosbg2").edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 0) {
                // Divider below searchbar
                Divider()
                
                // Main content
                VStack(spacing: 20) {
             
                  // Show "blackex" image when no workouts exist
                    if !workoutManager.hasWorkouts && !workoutManager.isLoadingWorkouts {
                        VStack(spacing: 16) {
                            Image("blackex")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxWidth: 250, maxHeight: 250)
                         
                            
                            Text("Build your perfect workout")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            Text("Create routines, track progress, and stay consistent. Once you add workouts, they'll show up here. ")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 45)
                        }
                        .padding(.top, 40)
                    }

                    // New Workout button
                    Button(action: {
                        print("Tapped New Workout")
                        HapticFeedback.generate()
                        showCreateWorkout = true
                    }) {
                        HStack(spacing: 6) {
                            Spacer()
                            Text("New Workout")
                                .font(.system(size: 15))
                                .fontWeight(.semibold)
                                .foregroundColor(Color("bg"))
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 18)
                        .frame(maxWidth: .infinity)
                        .background(Color.primary)
                        .cornerRadius(12)
                    }
                    .padding(.horizontal, 142)
                    .padding(.top, 10)
                    
                    
                    // Show loading indicator when loading workouts
                    if workoutManager.isLoadingWorkouts {
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.2)
                            
                            Text("Loading workouts...")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 40)
                    }
                    
                    // TODO: Show workout list when workouts exist
                    if workoutManager.hasWorkouts {
                        // This will be implemented later when we have workout data
                        Text("Workouts will be displayed here")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding(.top, 40)
                    }
                    
                    Spacer()
                }
            }
            .edgesIgnoringSafeArea(.bottom)
            .searchable(
                text: $searchText,
                placement: .automatic,
                prompt: "Search Workouts"
            )
            .focused($isSearchFieldFocused)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
        }
        .navigationBarBackButtonHidden(true)
        .onAppear {
            // Initialize WorkoutManager when view appears
            if !userEmail.isEmpty {
                workoutManager.initialize(userEmail: userEmail)
            }
        }
        .sheet(isPresented: $showCreateWorkout) {
            CreateWorkoutView()
        }
    }
    
    private var toolbarContent: some ToolbarContent {
        Group {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") {
                    selectedTab = 0
                    dismiss()
                }
                .foregroundColor(.accentColor)
            }
            
            ToolbarItem(placement: .principal) {
                Text("Log Workout")
                    .font(.headline)
            }
        }
    }
}

#Preview {
    NavigationView {
        LogWorkoutView(selectedTab: .constant(0))
    }
}
