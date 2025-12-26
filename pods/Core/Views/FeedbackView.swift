//
//  FeedbackView.swift
//  Pods

//

import SwiftUI

struct FeedbackView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var feedbackText: String = ""
    @State private var feedbackType: FeedbackType = .suggestion
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @FocusState private var isTextEditorFocused: Bool
    
    private let maxCharacters = 1000
    
    enum FeedbackType: String, CaseIterable {
        case bug = "Bug Report"
        case suggestion = "Suggestion"
        case other = "Other"
        
        var icon: String {
            switch self {
            case .bug: return "ladybug"
            case .suggestion: return "lightbulb"
            case .other: return "bubble.left"
            }
        }
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    Picker("Feedback Type", selection: $feedbackType) {
                        ForEach(FeedbackType.allCases, id: \.self) { type in
                            Label(type.rawValue, systemImage: type.icon)
                                .tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("What kind of feedback?")
                }
                
                Section {
                    TextEditor(text: $feedbackText)
                        .frame(minHeight: 200)
                        .focused($isTextEditorFocused)
                        .onChange(of: feedbackText) { newValue in
                            if newValue.count > maxCharacters {
                                feedbackText = String(newValue.prefix(maxCharacters))
                            }
                        }
                    
                    HStack {
                        Spacer()
                        Text("\(feedbackText.count)/\(maxCharacters)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("Your Feedback")
                } footer: {
                    Text("Your feedback helps us improve Metryc. Thank you!")
                        .font(.caption)
                }
            }
            .navigationTitle("Send Feedback")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Send") {
                        sendFeedback()
                    }
                    .fontWeight(.semibold)
                    .disabled(feedbackText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .alert("Feedback Status", isPresented: $showingAlert) {
                Button("OK") {
                    if alertMessage.contains("Thank you") {
                        dismiss()
                    }
                }
            } message: {
                Text(alertMessage)
            }
        }
        .onAppear {
            // Auto-focus the text editor
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isTextEditorFocused = true
            }
        }
    }
    
    private func sendFeedback() {
        let trimmedFeedback = feedbackText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedFeedback.isEmpty else { return }
        
        // Hide keyboard
        isTextEditorFocused = false
        
        // Get user info
        let userEmail = UserDefaults.standard.string(forKey: "userEmail") ?? "anonymous"
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
        
        // In a real implementation, you would send this to your backend
        // For now, we'll just log it and show a success message
        print("""
        📝 User Feedback Received:
        Type: \(feedbackType.rawValue)
        User: \(userEmail)
        App Version: \(appVersion) (\(buildNumber))
        iOS Version: \(UIDevice.current.systemVersion)
        Device: \(UIDevice.current.model)
        Feedback: \(trimmedFeedback)
        """)
        
        // TODO: Send feedback to backend endpoint
        // NetworkManagerTwo.shared.submitFeedback(...)
        
        // Show success message
        alertMessage = "Thank you for your feedback! We appreciate you taking the time to help us improve Metryc."
        showingAlert = true
    }
}

// MARK: - Preview

struct FeedbackView_Previews: PreviewProvider {
    static var previews: some View {
        FeedbackView()
    }
}