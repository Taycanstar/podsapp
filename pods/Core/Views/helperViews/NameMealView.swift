//
//  NameMealView.swift
//  Pods
//
//  Created by Dimi Nunez on 5/21/25.
//

import SwiftUI

struct NameMealView: View {
    @EnvironmentObject var mealFlow: MealFlow

    var body: some View {
        VStack(alignment: .center, spacing: 0) {
            Text("Personalize Your Recipe") // Title for this view
                .font(.title)
                .fontWeight(.bold)
                .padding(.horizontal, 25)
                .padding(.top, 60)
                .padding(.bottom, 20)
                .multilineTextAlignment(.center)

            Image("recipe03") // Image for this view
                .resizable()
                .scaledToFit()
                .frame(width: 375, height: 285)
                .padding(.horizontal)
                .padding(.bottom, 30)
            
            Text("Name your recipe and add foods") // Placeholder text
                .font(.system(size: 18, weight: .regular))
                .padding(.horizontal, 30)
                .multilineTextAlignment(.center)

            Spacer()

            VStack {
                Button(action: {
                    mealFlow.next()
                    HapticFeedback.generate()
                }) {
                    Text("Continue")
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
struct NameMealView_Previews: PreviewProvider {
    static var previews: some View {
        NameMealView()
            .environmentObject(MealFlow()) // Provide a dummy MealFlow for preview
    }
}
#endif
