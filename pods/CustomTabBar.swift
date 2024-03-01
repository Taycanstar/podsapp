import SwiftUI

struct CustomTabBar: View {
    @Binding var selectedTab: Int
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Traditional flat tab bar
            HStack {
                TabBarButton(iconName: "house", isSelected: selectedTab == 0) {
                    selectedTab = 0
                }
                Spacer()
                TabBarButton(iconName: "camera", isSelected: selectedTab == 1) {
                    selectedTab = 1
                }
                Spacer()
                TabBarButton(iconName: "person", isSelected: selectedTab == 2) {
                    selectedTab = 2
                }
            }
            .padding(.horizontal, 35)
            .padding(.vertical, 11)
            .background(tabBarBackgroundColor)
        }
    }

    var tabBarBackgroundColor: Color {
        colorScheme == .dark ? Color(rgb: 33, 33, 33) : .white
    }
}

// Custom tab button
struct TabBarButton: View {
    var iconName: String
    var isSelected: Bool
    var action: () -> Void
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        Button(action: action) {
            Image(systemName: isSelected ? iconName + ".fill" : iconName)
                .foregroundColor(isSelected ? selectedIconColor : .gray)
                .imageScale(.large)
        }
    }

    private var selectedIconColor: Color {
        colorScheme == .dark ? .white : .black
    }
}

// Helper function to define RGB color
extension Color {
    init(rgb red: CGFloat, _ green: CGFloat, _ blue: CGFloat) {
        self.init(red: red / 255, green: green / 255, blue: blue / 255)
    }
}
