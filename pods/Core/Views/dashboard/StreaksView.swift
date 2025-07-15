//
//  StreaksView.swift
//  pods
//
//  Created by Dimi Nunez on 7/15/25.
//

//
//  StreaksView.swift
//  Pods
//
//  Created by Dimi Nunez on 7/11/25.
//

import SwiftUI

struct StreaksView: View {
    @Binding var currentStreak: Int
    @Binding var longestStreak: Int
    @Binding var streakAsset: String
    @Binding var isVisible: Bool
    
    init(currentStreak: Binding<Int>, longestStreak: Binding<Int>, streakAsset: Binding<String>, isVisible: Binding<Bool> = .constant(true)) {
        self._currentStreak = currentStreak
        self._longestStreak = longestStreak
        self._streakAsset = streakAsset
        self._isVisible = isVisible
    }
    
    var body: some View {
        if isVisible {
            HStack(spacing: 3) {
                // Streak icon
                Image(streakAsset)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 24, height: 24)
                
                // Streak count
                Text("\(currentStreak)")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.primary)
            }
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        StreaksView(currentStreak: .constant(5), longestStreak: .constant(10), streakAsset: .constant("streaks1"), isVisible: .constant(true))
        StreaksView(currentStreak: .constant(15), longestStreak: .constant(20), streakAsset: .constant("streaks2"), isVisible: .constant(true))
        StreaksView(currentStreak: .constant(50), longestStreak: .constant(100), streakAsset: .constant("streaks3"), isVisible: .constant(true))
        StreaksView(currentStreak: .constant(200), longestStreak: .constant(365), streakAsset: .constant("streaks4"), isVisible: .constant(true))
        StreaksView(currentStreak: .constant(400), longestStreak: .constant(500), streakAsset: .constant("streaks5"), isVisible: .constant(false))
    }
    .padding()
    .background(Color("iosbg2"))
} 