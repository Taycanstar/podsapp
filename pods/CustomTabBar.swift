import SwiftUI

struct CustomTabBar: View {
    @Binding var selectedTab: Int
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Outer container layer
            ZStack {
                // Apply corner radius only to top corners
                TopRoundedRectangle(cornerRadius: 25)
                    .fill(outerContainerColor)
                    .frame(height: 90)
                    .shadow(radius: 5)
                    .edgesIgnoringSafeArea(.bottom) // Extend to the bottom edge

                // Floating tab bar
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
                .padding(.vertical, 10)
                .background(tabBarBackgroundColor)
                .cornerRadius(25)
                .padding(.horizontal, 20)
                .padding(.top, 0) // Adjust this padding to move the control up
                .padding(.bottom, 35)
                
                
            }
        }
    }

    var tabBarBackgroundColor: Color {
        colorScheme == .dark ? Color(rgb: 33, 33, 33) : Color(rgb: 250, 250, 250)
    }

    var outerContainerColor: Color {
        colorScheme == .dark ? .black : .white
    }
}

// Custom shape with top corners rounded
struct TopRoundedRectangle: Shape {
    var cornerRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()

        // Top left corner
        path.move(to: CGPoint(x: 0, y: cornerRadius))
        path.addArc(center: CGPoint(x: cornerRadius, y: cornerRadius), radius: cornerRadius, startAngle: Angle(degrees: 180), endAngle: Angle(degrees: 270), clockwise: false)
        
        // Top right corner
        path.addLine(to: CGPoint(x: rect.width - cornerRadius, y: 0))
        path.addArc(center: CGPoint(x: rect.width - cornerRadius, y: cornerRadius), radius: cornerRadius, startAngle: Angle(degrees: 270), endAngle: Angle(degrees: 0), clockwise: false)
        
        // Bottom right corner
        path.addLine(to: CGPoint(x: rect.width, y: rect.height))
        
        // Bottom left corner
        path.addLine(to: CGPoint(x: 0, y: rect.height))
        path.addLine(to: CGPoint(x: 0, y: cornerRadius))

        return path
    }
}

// Rest of the code (TabBarButton, Color extension) remains the same

struct TabBarButton: View {
    var iconName: String
    var isSelected: Bool
    var action: () -> Void
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        Button(action: action) {
            Image(systemName: isSelected ? iconName + ".fill" : iconName)
                .foregroundColor(isSelected ? selectedIconColor : .gray)
                .imageScale(.large) // Increase the size of the icon
                .font(.system(size: 16)) // Adjust the font size for bigger icons
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
