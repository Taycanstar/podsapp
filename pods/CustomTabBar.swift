import SwiftUI

// CustomTabBar
struct CustomTabBar: View {
    @Binding var selectedTab: Int
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            HStack {
                // Pass the action directly to avoid confusion with parameter labels
                TabBarButton(iconName: "house", isSelected: selectedTab == 0) { selectedTab = 0 }
                    .foregroundColor(selectedTab == 0 ? selectedIconColor : .gray)
                Spacer()
                TabBarButton(iconName: "camera", isSelected: selectedTab == 1) { selectedTab = 1 }
                    .foregroundColor(selectedTab == 1 ? selectedIconColor : .gray)
                Spacer()
                TabBarButton(iconName: "person", isSelected: selectedTab == 2) { selectedTab = 2 }
                    .foregroundColor(selectedTab == 2 ? selectedIconColor : .gray)
            }
            .padding(.horizontal, 35)
            .padding(.vertical, 11)
            .background(tabBarBackgroundColor)
        }
    }

    var tabBarBackgroundColor: Color {
        if selectedTab == 1 { // Camera tab is selected
            return .black
        } else {
            return colorScheme == .dark ? Color(rgb: 33, 33, 33) : .white
        }
    }

    var selectedIconColor: Color {
        // When the camera tab is selected, ensure icon visibility against the black background
        if selectedTab == 1 {
            return .white
        } else {
            // Adjust icon color based on system theme for other tabs
            return colorScheme == .dark ? .white : .black
        }
    }
}

// Custom tab button
struct TabBarButton: View {
    var iconName: String
    var isSelected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: isSelected ? iconName + ".fill" : iconName)
                .imageScale(.large)
        }
    }
}

// Helper function to define RGB color
extension Color {
    init(rgb red: CGFloat, _ green: CGFloat, _ blue: CGFloat) {
        self.init(red: red / 255, green: green / 255, blue: blue / 255)
    }
}
