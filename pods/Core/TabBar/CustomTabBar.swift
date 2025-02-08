import SwiftUI

// CustomTabBar
struct CustomTabBar: View {
    @Binding var selectedTab: Int
    @Environment(\.colorScheme) var colorScheme
    @Binding var showVideoCreationScreen: Bool
    @Binding var showQuickPodView: Bool
    @Binding var showNewSheet: Bool
    @EnvironmentObject var sharedViewModel: SharedViewModel

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            ZStack(alignment: .top) {
                // This rectangle acts as the top border
                Rectangle()
                    .frame(height: 0.5)
                    .foregroundColor(sharedViewModel.isItemViewActive ? Color(uiColor: UIColor.darkGray) : (colorScheme == .dark ? Color(uiColor: UIColor.darkGray) : Color(red: 0.9, green: 0.9, blue: 0.9)))
                    .zIndex(1)

                HStack {
//                    Spacer()
//                    TabBarButton(iconName: "house", label: "Home", isSelected: selectedTab == 0, iconSize: 16) { selectedTab = 0 }
//                        .foregroundColor(selectedTab == 0 ? selectedIconColor : .gray)
//                    
//                    Spacer() // Equal spacing
                    
                    TabBarButton(iconName: "folder", label: "Pods", isSelected: selectedTab == 0, iconSize: 16) { selectedTab = 0 }
                        .foregroundColor(selectedTab == 0 ? selectedIconColor : .gray)
                    
                    Spacer() // Equal spacing

                    TabBarButton(iconName: "plus.circle.fill", isSelected: selectedTab == 1, iconSize: 30) {
//                        showNewSheet = true
                        showQuickPodView = true
                    }
                    .foregroundColor(.accentColor)
                    .offset(y: -5)
                    
                    Spacer() // Equal spacing

//                    TabBarButton(iconName: "person.2", label: "Friends", isSelected: selectedTab == 3, iconSize: 16) { selectedTab = 3 }
//                        .foregroundColor(selectedTab == 3 ? selectedIconColor : .gray)
//
//                    Spacer() // Equal spacing

                    TabBarButton(iconName: "ellipsis.circle", label: "More", isSelected: selectedTab == 4, iconSize: 16) { selectedTab = 4 }
                        .foregroundColor(selectedTab == 4 ? selectedIconColor : .gray)
//                    Spacer()
                }
//                .padding(.horizontal, 26)
                .padding(.horizontal, 46)
                .padding(.top, 11)
                .background(Material.ultraThin)

            }
        }
    }


    // Updated the background color to adapt to light/dark mode
    var tabBarBackgroundColor: Color {
        if sharedViewModel.isItemViewActive { // Check if ItemView is active
            
            return .black
        } else if selectedTab == 1 { // Camera tab is selected
            return .black
        } else if selectedTab == 5 { // Saved for when tab is like for u page
            return .black
        } else {
            // Modified to adapt to the color scheme
            return colorScheme == .dark ? Color(uiColor: UIColor.systemBackground) : .white
        }
    }

    // Updated the icon color to adapt to light/dark mode
    var selectedIconColor: Color {
        // When the camera tab is selected, ensure icon visibility against the black background
        if sharedViewModel.isItemViewActive { // Check if ItemView is active
            return .white
        } else if selectedTab == 1 { // Camera tab is selected
            return .white
        } else if selectedTab == 5 { // Saved for when tab is like for u page
            return .white
        } else {
            // Modified to adapt to the color scheme
            return colorScheme == .dark ? .white : .black
        }
    }
}

// Custom tab button
struct TabBarButton: View {
    var iconName: String
    var label: String?  // Make label optional
    var isSelected: Bool
    var iconSize: CGFloat = UIFont.preferredFont(forTextStyle: .title1).pointSize
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack {
                Image(systemName: isSelected ? iconName + ".fill" : iconName)
                    .imageScale(.large)
                    .font(.system(size: iconSize))
                if let label = label {  // Only show label if provided
                    Text(label)
                        .font(.caption)
                        .padding(.top, 0.5)
                }
            }
        }
    }
}

// Helper function to define RGB color
extension Color {
    init(rgb red: CGFloat, _ green: CGFloat, _ blue: CGFloat) {
        self.init(red: red / 255, green: green / 255, blue: blue / 255)
    }
}
