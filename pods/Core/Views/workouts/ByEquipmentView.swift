//
//  ByEquipmentView.swift
//  Pods
//
//  Created by Dimi Nunez on 6/22/25.
//

import SwiftUI

struct EquipmentSelection: Hashable {
    let name: String
    let type: String
}

struct ByEquipmentView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var navigationPath = NavigationPath()
    
    let onExercisesSelected: ([ExerciseData]) -> Void
    
    init(onExercisesSelected: @escaping ([ExerciseData]) -> Void) {
        self.onExercisesSelected = onExercisesSelected
    }
    
    // Equipment types based on both explicit equipment field AND exercise names (32 total)
    private let equipmentTypes = [
        // Primary Equipment (explicit in equipment field)
        ("Barbells", "barbells"),           
        ("Dumbbells", "dumbbells"),                  // "Dumbbell" - 31+ exercises  
        ("Cable", "crossovercable"),                 // "Cable" - 26+ exercises
        ("Smith Machine", "smith"),                  // "Smith machine" - 12+ exercises
        ("Hammerstrength (Leverage) Machine", "hammerstrength"), // "Leverage machine" - 11+ exercises
        ("Kettlebells", "kbells"),                   // "Kettlebell" - 9+ exercises
        ("Resistance Bands", "handlebands"),         // "Band" - 7+ exercises
        ("Stability (Swiss) Ball", "swissball"),     // "Stability ball" - 4+ exercises
        ("Battle Ropes", "battleropes"),             // "Rope" - 3+ exercises
        ("EZ Bar", "ezbar"),                         // "EZ Barbell" - 2+ exercises
        ("BOSU Balance Trainer", "bosu"),            // "Bosu ball" - 1+ exercise
        ("Sled", "sled"),                           // "Sled machine" - 1+ exercise
        ("Medicine Balls", "medballs"),              // "Medicine Ball" - 1+ exercise
        ("Body weight", ""),                         // "Body weight" - 67+ exercises
        
        // Bench Equipment (implied by exercise names)
        ("Flat Bench", "flatbench"),                // "Bench Press", "Bench Dip" - 40+ exercises
        ("Decline Bench", "declinebench"),           // "Decline Bench Press" - 5+ exercises
        ("Preacher Curl Bench", "preachercurlmachine"),   // "Preacher Curl" - 15+ exercises
        ("Incline Bench", "inclinebench"),           // "Incline Bench Press" - 15+ exercises
        
        // Machine Equipment (implied by exercise names)
        ("Lat Pulldown Cable", "latpulldown"),      // "Lat Pulldown" - 10+ exercises
        ("Leg Extension Machine", "legextmachine"),         // "Leg Extension" - 8+ exercises
        ("Leg Curl Machine", "legcurlmachine"),     // "Leg Curl" - 6+ exercises
        ("Calf Raise Machine", "calfraisesmachine"),             // "Calf Raise" - 10+ exercises
        ("Row Machine", "seatedrow"),              // "Seated Row" - 5+ exercises
        ("Leg Press", "legpress"),                  // "Leg Press" - 5+ exercises
        
        // Bar Equipment (implied by exercise names)
        ("Pull up Bar", "pullupbar"),               // "Pull-up", "Chin-up" - 10+ exercises
        ("Dip (Parallel) Bar", "dipbar"),          // "Dip" exercises - 5+ exercises
        
        // Additional Equipment (implied by exercise names)
        ("Squat Rack", "squatrack"),               // Heavy barbell exercises
        ("Box", "box"),                            // "Box Jump", "Box Squat" - 5+ exercises
        ("Platforms", "platforms"),                // Step-up exercises, platform work
        
        // Specialty Equipment (implied by exercise names)  
        ("Hack Squat Machine", "hacksquat"),       // "Hack Squat" exercises
        ("Shoulder Press Machine", "shoulderpress"), // Machine shoulder press exercises
        ("Triceps Extension Machine", "tricepext"), // Machine tricep exercises
        ("Biceps Curl Machine", "bicepscurlmachine"),   // Machine bicep curl exercises
        ("Ab Crunch Machine", "abcrunch"),          // Machine ab exercises
        ("Preacher Curl Machine", "preachercurlmachine"),   // "Preacher Curl" - 15+ exercises
    ]
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
        VStack(spacing: 0) {
            // Background color
            Color(.systemBackground)
                .ignoresSafeArea(.all)
                .overlay(contentView)
        }
        .navigationTitle("By Equipment")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    dismiss()
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(.primary)
                }
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") {
                    dismiss()
                }
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.accentColor)
            }
        }
        .searchable(text: $searchText, prompt: "Search equipment")
            .navigationDestination(for: EquipmentSelection.self) { selection in
                EquipmentExercisesView(
                    equipmentName: selection.name,
                    equipmentType: selection.type,
                    onExercisesSelected: { exercises in
                        onExercisesSelected(exercises)
                        dismiss() // Dismiss the entire sheet
                    }
                )
            }
        }
    }
    
    // MARK: - Content View
    private var contentView: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(Array(filteredEquipment.enumerated()), id: \.offset) { index, equipment in
                    Button(action: {
                        HapticFeedback.generate()
                        let selection = EquipmentSelection(name: equipment.0, type: equipment.1)
                        navigationPath.append(selection)
                    }) {
                        HStack(spacing: 16) {
                            // Equipment image or SF Symbol
                            Group {
                                if equipment.1.isEmpty {
                                    // Body weight - use SF Symbol
                                    Image(systemName: "figure.strengthtraining.functional")
                                        .font(.system(size: 20, weight: .medium))
                                        .foregroundColor(.primary)
                                } else {
                                    // Try to load equipment image
                                    if let image = UIImage(named: equipment.1) {
                                        Image(uiImage: image)
                                            .resizable()
                                            .aspectRatio(contentMode: .fit)
                                    } else {
                                        // Fallback SF Symbol
                                        Image(systemName: "dumbbell")
                                            .font(.system(size: 20, weight: .medium))
                                            .foregroundColor(.primary)
                                    }
                                }
                            }
                            .frame(width: 45, height: 45)
                            
                            Text(equipment.0)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 16)
                        .background(Color(.systemBackground))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    if index < filteredEquipment.count - 1 {
                        Divider()
                            .padding(.leading, 62)
                    }
                }
            }
        }
        .background(Color(.systemBackground))
    }
    
    // MARK: - Computed Properties
    private var filteredEquipment: [(String, String)] {
        if searchText.isEmpty {
            return equipmentTypes
        } else {
            return equipmentTypes.filter { equipment in
                equipment.0.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
}

#Preview {
    NavigationView {
        ByEquipmentView { exercises in
            print("Selected exercises: \(exercises.map { $0.name })")
        }
    }
}
