//
//  FoodContainerView.swift
//  Pods
//
//  Created by Dimi Nunez on 2/10/25.
//

import Foundation
import SwiftUI

enum FoodNavigationDestination: Hashable {
    case logFood
}

struct FoodContainerView: View {
    @State private var path = NavigationPath()
    @Binding var selectedTab: Int
    
    var body: some View {
        NavigationStack(path: $path) {
            LogFood(selectedTab: $selectedTab)
                .navigationDestination(for: FoodNavigationDestination.self) { destination in
                    switch destination {
                    case .logFood:
                        LogFood(selectedTab: $selectedTab)
                    }
                }
        }
    }
}
