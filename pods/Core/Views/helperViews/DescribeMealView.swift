//
//  DescribeMealView.swift
//  Pods
//
//  Created by Dimi Nunez on 5/21/25.
//

import SwiftUI

struct DescribeMealView: View {
    @EnvironmentObject var mealFlow: MealFlow

    var body: some View {
        VStack(alignment: .center, spacing: 0) {
            Text("Bring Your Recipe Together") // Title for this view
                .font(.title)
                .fontWeight(.bold)
                .padding(.horizontal, 25)
                .padding(.top, 60)
                .padding(.bottom, 20)
                .multilineTextAlignment(.center)

            Image("recipe00") // Image for this view
                .resizable()
                .scaledToFit()
             .frame(width: 375, height: 200)
                .padding(.horizontal)
                .padding(.bottom, 30)
            
            Text("Describe your complete recipe in the search bar") // Placeholder text
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
struct DescribeMealView_Previews: PreviewProvider {
    static var previews: some View {
        DescribeMealView()
            .environmentObject(MealFlow()) // Provide a dummy MealFlow for preview
    }
}
#endif
