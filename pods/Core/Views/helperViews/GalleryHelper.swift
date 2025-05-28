//
//  GalleryHelper.swift
//  Pods
//
//  Created by Dimi Nunez on 5/26/25.
//

import SwiftUI

struct GalleryHelper: View {
    @EnvironmentObject var scanFlow: ScanFlow
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(alignment: .center, spacing: 0) {
            Text("Select From Gallery") // Title
                .font(.title)
                .fontWeight(.bold)
                .padding(.horizontal, 25)
                .padding(.top, 60)
                .padding(.bottom, 20)
                .multilineTextAlignment(.center)

            Image("scan1") // Image
                .resizable()
                .scaledToFit()
                .frame(width: 375, height: 375)
                .padding(.horizontal)
                .padding(.bottom, 30)
            
            Text("Select a  photo from your gallery to analyze foods and see nutrition details.") // Placeholder text
                .font(.system(size: 18, weight: .regular))
                .padding(.horizontal, 30)
                .multilineTextAlignment(.center)

            Spacer()

            VStack {
                Button(action: {
                    HapticFeedback.generate() // Assuming HapticFeedback is available
                    if scanFlow.currentStep.rawValue == ScanStep.allCases.count - 1 {
                        // This is the last step - mark as seen and dismiss
                        UserDefaults.standard.hasSeenScanFlow = true
                        dismiss()
                    } else {
                        scanFlow.next()
                    }
                }) {
                    Text(scanFlow.currentStep.rawValue == ScanStep.allCases.count - 1 ? "Finish" : "Continue")
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
    }
}

#if DEBUG
struct GalleryHelper_Previews: PreviewProvider {
    static var previews: some View {
        GalleryHelper()
            .environmentObject(ScanFlow()) // Provide a dummy ScanFlow for preview
    }
}
#endif
