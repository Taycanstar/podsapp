//
//  NewMenuView.swift
//  Pods
//
//  Created by Dimi Nunez on 5/21/25.
//

import SwiftUI

struct NewMenuView: View {
    @EnvironmentObject var logFlow: LogFlow
    // @Environment(\.dismiss) var dismissFlow

    var body: some View {
        VStack(spacing: 0) {
            Spacer() // Pushes content towards the center vertically

            Image("logfood0") // Ensure "logfood0" is in your Assets.xcassets
                .resizable()
                .scaledToFit()
                .frame(width: 180, height: 180) // Adjusted size
                .padding(.bottom, 30)

            VStack(alignment: .leading, spacing: 25) { // Increased spacing for clarity
                DescriptionRowView(iconName: "pencil.and.ruler.fill", text: "Describe your food or select from favorites to log your meals")
                DescriptionRowView(iconName: "mic.fill", text: "Log your meal with your voice")
                DescriptionRowView(iconName: "camera.viewfinder", text: "Snap a photo or scan a barcode to log your meal instantly") // Changed to camera.viewfinder for photo/scan
            }
            .padding(.horizontal, 30)
            .padding(.bottom, 20)
            
            Spacer()
            Spacer()

            // Bottom Bar with Continue Button
            VStack {
                Button(action: {
                    // HapticFeedback.generate() // Uncomment if HapticFeedback is implemented
                    logFlow.next() // Navigates to the next step or handles flow completion
                }) {
                    // Text should be "Get Started" or "Finish" based on whether it's the last step.
                    // The LogFlowContainerView can manage this text if needed, or it can be fixed here.
                    Text(logFlow.currentStep.rawValue == LogStep.allCases.count - 1 ? "Finish" : "Get Started")
                        .font(.system(size: 18, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color("background"))
                        .foregroundColor(Color("bg"))
                        .cornerRadius(12)
                }
                .padding(.horizontal)
                .padding(.vertical, 16)
            }
            .padding(.bottom, 24)
            .background(Material.ultraThin)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color("bg").edgesIgnoringSafeArea(.all))
        // NavigationBar elements are handled by LogFlowContainerView
    }
}

// Reusable view for the icon + text rows
struct DescriptionRowView: View {
    let iconName: String
    let text: String

    var body: some View {
        HStack(spacing: 20) { // Increased spacing
            Image(systemName: iconName)
                .font(.title2)
                .foregroundColor(.primary) // Use accent color for icons
                .frame(width: 35, alignment: .leading) // Ensure icons align well
            Text(text)
                .font(.body)
        }
    }
}

// Preview
#if DEBUG
struct NewMenuView_Previews: PreviewProvider {
    static var previews: some View {
        // Create a container to properly preview the flow context
        NavigationView { // A simple NavigationView for previewing nav bar items context
            NewMenuView()
                .environmentObject(LogFlow()) // Provide a dummy LogFlow for preview
        }
    }
}
#endif
