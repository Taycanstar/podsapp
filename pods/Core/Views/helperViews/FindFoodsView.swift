//
//  FindFoodsView.swift
//  Pods
//
//  Created by Dimi Nunez on 5/21/25.
//

import SwiftUI

struct FindFoodsView: View {
    @EnvironmentObject var mealFlow: MealFlow
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(alignment: .center, spacing: 0) {
            Text("Add Foods to Your Recipe") // Title for this view
                .font(.title)
                .fontWeight(.bold)
                .padding(.horizontal, 25)
                .padding(.top, 60)
                .padding(.bottom, 20)
                .multilineTextAlignment(.center)

            Image("recipe05") // Image for this view
                .resizable()
                .scaledToFit()
                .frame(width: 375, height: 285)
                .padding(.horizontal)
                .padding(.bottom, 30)
            
            Text("Find foods and tap + to add foods to your recipe") // Placeholder text
                .font(.system(size: 18, weight: .regular))
                .padding(.horizontal, 35)
                .multilineTextAlignment(.center)

            Spacer()

            VStack {
                Button(action: {
                    print("🔍 FindFoodsView - Finish button tapped")
                    HapticFeedback.generate()   
                    // Complete the flow - this will trigger the container to dismiss
                    mealFlow.completeFlow()
                }) {
                    Text("Finish") // Button text for the last step
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
struct FindFoodsView_Previews: PreviewProvider {
    static var previews: some View {
        FindFoodsView()
            .environmentObject(MealFlow()) // Provide a dummy MealFlow for preview
    }
}
#endif
