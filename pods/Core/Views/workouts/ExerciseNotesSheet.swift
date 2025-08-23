//
//  ExerciseNotesSheet.swift
//  pods
//
//  Created by Dimi Nunez on 8/23/25.
//

import SwiftUI

struct ExerciseNotesSheet: View {
    @Binding var notes: String
    let exerciseId: Int
    let exerciseName: String
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isTextFieldFocused: Bool
    @State private var tempNotes: String = ""
    @State private var showCharacterWarning = false
    
    private let maxCharacters = 500
    private let warningThreshold = 450
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header with exercise name
                VStack(alignment: .leading, spacing: 8) {
                    Text("Exercise")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(exerciseName)
                        .font(.headline)
                        .foregroundColor(.primary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color(.systemGray6))
                
                // Text editor with enhanced features
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        ZStack(alignment: .topLeading) {
                            if tempNotes.isEmpty {
                                Text("Add notes about form, technique, modifications, or personal observations...")
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 8)
                                    .allowsHitTesting(false)
                            }
                            
                            TextEditor(text: $tempNotes)
                                .focused($isTextFieldFocused)
                                .scrollContentBackground(.hidden)
                                .padding(.horizontal, -4)
                                .frame(minHeight: 300)
                                .onChange(of: tempNotes) { _, newValue in
                                    // Enforce character limit
                                    if newValue.count > maxCharacters {
                                        tempNotes = String(newValue.prefix(maxCharacters))
                                        // Haptic feedback when hitting limit
                                        let impactFeedback = UIImpactFeedbackGenerator(style: .rigid)
                                        impactFeedback.impactOccurred()
                                    }
                                    // Show warning when approaching limit
                                    showCharacterWarning = newValue.count >= warningThreshold
                                }
                        }
                        .padding()
                        
                        // Character count footer
                        HStack {
                            if showCharacterWarning {
                                Label(
                                    tempNotes.count >= maxCharacters ? "Character limit reached" : "Approaching limit",
                                    systemImage: "exclamationmark.triangle.fill"
                                )
                                .font(.caption)
                                .foregroundColor(tempNotes.count >= maxCharacters ? .red : .orange)
                            }
                            
                            Spacer()
                            
                            Text("\(tempNotes.count)/\(maxCharacters)")
                                .font(.caption)
                                .foregroundColor(characterCountColor)
                        }
                        .padding(.horizontal)
                        .padding(.bottom)
                    }
                }
                
                Spacer()
            }
            .navigationTitle("Notes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.primary)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        saveNotes()
                    }
                    .fontWeight(.semibold)
                    .disabled(tempNotes.isEmpty && notes.isEmpty)
                }
            }
        }
        .onAppear {
            tempNotes = notes
            // Auto-focus with slight delay for smooth presentation
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isTextFieldFocused = true
            }
        }
        .interactiveDismissDisabled(!tempNotes.isEmpty && tempNotes != notes)
    }
    
    private var characterCountColor: Color {
        if tempNotes.count >= maxCharacters {
            return .red
        } else if tempNotes.count >= warningThreshold {
            return .orange
        } else {
            return .secondary
        }
    }
    
    private func saveNotes() {
        // Trim whitespace
        let trimmedNotes = tempNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Update the binding
        notes = trimmedNotes
        
        // Save to service
        Task {
            await ExerciseNotesService.shared.saveNotes(trimmedNotes, for: exerciseId)
        }
        
        // Success haptic feedback
        let notificationFeedback = UINotificationFeedbackGenerator()
        notificationFeedback.prepare()
        notificationFeedback.notificationOccurred(.success)
        
        dismiss()
    }
}

