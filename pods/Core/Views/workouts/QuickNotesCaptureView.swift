//
//  QuickNotesCaptureView.swift
//  pods
//
//  Created by Dimi Nunez on 8/23/25.
//

import SwiftUI
import UIKit

struct QuickNotesCaptureView: View {
    @Binding var notes: String
    let exerciseId: Int
    let exerciseName: String
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isFocused: Bool
    @State private var tempNotes: String = ""
    @State private var showCharacterWarning = false
    
    private let maxCharacters = 500
    private let warningThreshold = 450
    
    init(notes: Binding<String>, exerciseId: Int, exerciseName: String) {
        self._notes = notes
        self.exerciseId = exerciseId
        self.exerciseName = exerciseName
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Handle indicator
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.secondary.opacity(0.3))
                .frame(width: 36, height: 4)
                .padding(.top, 8)
            
            // Exercise context
            Text(exerciseName)
                .font(.headline)
                .foregroundColor(.primary)
                .padding(.top, 16)
                .padding(.horizontal)
            
            // Text input with proper styling
            VStack(alignment: .leading, spacing: 8) {
                ZStack(alignment: .topLeading) {
                    if tempNotes.isEmpty {
                        Text("Add notes about form, modifications, or progress...")
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .allowsHitTesting(false)
                    }
                    
                    TextEditor(text: $tempNotes)
                        .focused($isFocused)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .scrollContentBackground(.hidden)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                        .frame(minHeight: 100, maxHeight: 200)
                        .onChange(of: tempNotes) { _, newValue in
                            // Enforce character limit
                            if newValue.count > maxCharacters {
                                tempNotes = String(newValue.prefix(maxCharacters))
                            }
                            // Show warning when approaching limit
                            showCharacterWarning = newValue.count >= warningThreshold
                        }
                }
                
                // Character count and warning
                HStack {
                    Text("\(tempNotes.count)/\(maxCharacters)")
                        .font(.caption)
                        .foregroundColor(characterCountColor)
                    
                    if showCharacterWarning {
                        Text("Approaching character limit")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                    
                    Spacer()
                }
            }
            .padding()
            
            Spacer()
            
            // Action buttons
            HStack(spacing: 16) {
                Button("Cancel") {
                    dismiss()
                }
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color(.systemGray6))
                .cornerRadius(10)
                
                Button("Save") {
                    saveNotes()
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(tempNotes.isEmpty ? Color.gray : Color.blue)
                .cornerRadius(10)
                .disabled(tempNotes.isEmpty)
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
        .background(Color(.systemBackground))
        .cornerRadius(16, corners: [.topLeft, .topRight])
        .onAppear {
            tempNotes = notes
            // Small delay to ensure smooth presentation before keyboard appears
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                isFocused = true
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
        // Update the binding
        notes = tempNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Save to service
        Task {
            await ExerciseNotesService.shared.saveNotes(notes, for: exerciseId)
        }
        
        // Haptic feedback for save
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.prepare()
        impactFeedback.impactOccurred()
        
        dismiss()
    }
}

// Helper extension for corner radius on specific corners
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners
    
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

