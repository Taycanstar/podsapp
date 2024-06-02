//
//  SplashScreenView.swift
//  pods
//
//  Created by Dimi Nunez on 5/30/24.
//

import SwiftUI

struct SplashScreenView: View {
    @State private var isActive = false
    @State private var size = 0.8
    @State private var opacity = 0.5
    var body: some View {
        if isActive {
            ContentView()
        } else {
            ZStack{
                Color(rgb: 71, 98, 246
                )
                .edgesIgnoringSafeArea(.all)
                Image("clear-logo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 200, height: 200)
            }
            .scaleEffect(size)
            .opacity(opacity)
            .onAppear{
               
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0){
                    self.isActive = true
                }
            }
        }
 
    }
}

#Preview {
    SplashScreenView()
}
