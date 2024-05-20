//
//  PlayerContainerView.swift
//  pods
//
//  Created by Dimi Nunez on 4/28/24.
//

import SwiftUI

struct PlayerContainerView: View {
    @State private var index = 0
//    @State private var videos = MockData().videos
    @State var items: [PodItem]
    @Environment(\.presentationMode) var presentationMode
    @State private var currentIndex = 0
    @EnvironmentObject var sharedViewModel: SharedViewModel

    
  
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            PlayerPageView(items: $items, currentIndex: $currentIndex)
          
                .background(Color.black
                    .edgesIgnoringSafeArea(.all))
                .edgesIgnoringSafeArea(.all)
               
            
//                .navigationBarItems(leading: backButton)
//                .navigationBarTitle(displayTitle(), displayMode: .inline)
            // Custom navigation bar items using toolbar
                         .toolbar {
                             ToolbarItem(placement: .navigationBarLeading) {
                                 backButton
                             }
                             ToolbarItem(placement: .principal) {
                                 Text(displayTitle())
                                     .foregroundColor(.white)
                                     .font(.headline)
                             }
                         }
                         .onAppear {
                                    sharedViewModel.isItemViewActive = true
                                }
                                .onDisappear {
                                    sharedViewModel.isItemViewActive = false
                                }
                      
                .navigationBarBackButtonHidden(true)
        
               }
        

        }
    

    private var backButton: some View {
        
        Button(action: {
            presentationMode.wrappedValue.dismiss()
        }) {
            Image(systemName: "chevron.left").foregroundColor(.white)
                .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 2)
                .font(.system(size: 20))
        }
    }
    
    private func displayTitle() -> String {
           if items.indices.contains(currentIndex) {
               return items[currentIndex].metadata // Assuming metadata is a String
           }
           return "No Video"
       }
    
    
}
