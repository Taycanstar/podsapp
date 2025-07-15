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
    
    init(currentStreak: Binding<Int>, longestStreak: Binding<Int>, streakAsset: Binding<String>) {
        self._currentStreak = currentStreak
        self._longestStreak = longestStreak
        self._streakAsset = streakAsset
    }
    
    var body: some View {
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
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("StreakUpdatedNotification"))) { notification in
            if let streakData = notification.object as? UserStreakData {
                currentStreak = streakData.currentStreak
                longestStreak = streakData.longestStreak
                streakAsset = streakData.streakAsset
            }
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        StreaksView(currentStreak: .constant(5), longestStreak: .constant(10), streakAsset: .constant("streaks1"))
        StreaksView(currentStreak: .constant(15), longestStreak: .constant(20), streakAsset: .constant("streaks2"))
        StreaksView(currentStreak: .constant(50), longestStreak: .constant(100), streakAsset: .constant("streaks3"))
        StreaksView(currentStreak: .constant(200), longestStreak: .constant(365), streakAsset: .constant("streaks4"))
        StreaksView(currentStreak: .constant(400), longestStreak: .constant(500), streakAsset: .constant("streaks5"))
    }
    .padding()
    .background(Color("iosbg2"))
} 