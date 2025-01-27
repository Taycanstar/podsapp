import SwiftUI

// CustomTabBar
struct CustomTabBar: View {
    @Binding var selectedTab: Int
    @Environment(\.colorScheme) var colorScheme
    @Binding var showVideoCreationScreen: Bool
    @Binding var showQuickPodView: Bool
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
                    // Pass the action directly to avoid confusion with parameter labels
                    TabBarButton(iconName: "house", label: "Home", isSelected: selectedTab == 0, iconSize: 16) { selectedTab = 0 }
                        .foregroundColor(selectedTab == 0 ? selectedIconColor : .gray)
                    Spacer()
                 
                    TabBarButton(iconName: "plus.circle.fill", isSelected: selectedTab == 1, iconSize: 30) {
                        showQuickPodView = true
                    }
//                        .foregroundColor(selectedTab == 1 ? selectedIconColor : .gray)
                    .foregroundColor(.accentColor)
                    Spacer()
                    TabBarButton(iconName: "ellipsis.circle", label: "More", isSelected: selectedTab == 2, iconSize: 16) { selectedTab = 2 }
                        .foregroundColor(selectedTab == 2 ? selectedIconColor : .gray)
                    Spacer()
                    TabBarButton(iconName: "folder", label: "Pods", isSelected: selectedTab == 3, iconSize: 16) { selectedTab = 3 }
                        .foregroundColor(selectedTab == 3 ? selectedIconColor : .gray)
                }
                .padding(.horizontal, 45)
                .padding(.top, 11)
                .background(
                    Material.ultraThin)
                
            }
           
          
        }


    }

    // Updated the background color to adapt to light/dark mode
    var tabBarBackgroundColor: Color {
        if sharedViewModel.isItemViewActive { // Check if ItemView is active
            
            return .black
        } else if selectedTab == 1 { // Camera tab is selected
            return .black
        } else if selectedTab == 4 { // Saved for when tab is like for u page
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
        } else if selectedTab == 4 { // Saved for when tab is like for u page
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
