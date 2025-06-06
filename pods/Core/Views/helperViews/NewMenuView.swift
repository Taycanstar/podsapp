//
//  NewMenuView.swift
//  Pods
//
//  Created by Dimi Nunez on 5/21/25.
//

import SwiftUI

struct NewMenuView: View {
    @EnvironmentObject var logFlow: LogFlow
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(alignment: .center, spacing: 0) {
                Text("Log Meals Your Way")
                .font(.title)
                .fontWeight(.bold)
                .padding(.horizontal, 25)
                .padding(.top, 60)
                .padding(.bottom, 20)
                .multilineTextAlignment(.center) 

            Image("logfood0") // Ensure "logfood0" is in your Assets.xcassets
                .resizable()
                .scaledToFit()
                .frame(width: 375, height: 285) // Matched TapPlusView image frame
                .padding(.horizontal) // Matched TapPlusView image padding
                .padding(.bottom, 30) // Kept original bottom padding

            VStack(alignment: .leading, spacing: 25) { // Increased spacing for clarity
                DescriptionRowView(iconName: "magnifyingglass", text: "Describe your food or select from favorites to log your meals")
                DescriptionRowView(iconName: "mic", text: "Log your meal with your voice")
                DescriptionRowView(iconName: "barcode.viewfinder", text: "Snap a photo or scan a barcode to log your meal instantly") // Changed to camera.viewfinder for photo/scan
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 20)
            
            Spacer()
            Spacer()

            // Bottom Bar with Continue Button
            VStack {
                Button(action: {
                    print("🔍 NewMenuView - Finish button tapped")
                    HapticFeedback.generate()
                    // Complete the flow - this will trigger the container to dismiss
                    logFlow.completeFlow()
                }) {
                    Text("Finish")
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
                .fixedSize(horizontal: false, vertical: true) // Allow text to wrap
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
