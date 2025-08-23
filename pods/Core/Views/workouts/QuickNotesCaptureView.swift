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
        NavigationView {
            VStack {
                // Text input with proper height
                ZStack(alignment: .topLeading) {
                    if tempNotes.isEmpty {
                        Text("Add your notes here...")
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 12)
                            .allowsHitTesting(false)
                    }
                    
                    TextEditor(text: $tempNotes)
                        .focused($isFocused)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 8)
                        .scrollContentBackground(.hidden)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                        .frame(minHeight: 40, maxHeight: 200) // Start single line, grow to max 9 lines
                        .onChange(of: tempNotes) { _, newValue in
                            // Enforce character limit silently
                            if newValue.count > maxCharacters {
                                tempNotes = String(newValue.prefix(maxCharacters))
                            }
                        }
                }
                .padding(.horizontal)
                .padding(.top, 20)
                
                Spacer()
            }
            .navigationTitle("Add Notes")
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
                    // Remove disabled state to allow saving empty notes
                }
            }
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Button("Clear") {
                        clearNotes()
                    }
                    .font(.system(size: 17, weight: .regular))
                    .foregroundColor(tempNotes.isEmpty ? Color(.systemGray3) : .accentColor)
                    .disabled(tempNotes.isEmpty)
                    
                    Spacer()
                }
            }
        }
        .onAppear {
            tempNotes = notes
            // Auto-focus with slight delay for smooth presentation
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
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
    
    private func clearNotes() {
        tempNotes = ""
        
        // Haptic feedback for clear action
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.prepare()
        impactFeedback.impactOccurred()
    }
    
    private func saveNotes() {
        // Update the binding (allow empty strings to clear notes)
        notes = tempNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Save to service (empty string will clear the notes)
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

