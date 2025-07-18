import SwiftUI

// CustomTabBar
struct CustomTabBar: View {
    @Binding var selectedTab: Int
    @Environment(\.colorScheme) var colorScheme
    @Binding var showVideoCreationScreen: Bool
    @Binding var showQuickPodView: Bool
    @Binding var showNewSheet: Bool
    @EnvironmentObject var sharedViewModel: SharedViewModel
    
    // Add states for food scanning/voice input
    @State private var showFoodScanner = false
    @State private var showVoiceRecording = false
    
    // Add states for barcode confirmation (same as ContentView)
    @State private var showConfirmFoodView = false
    @State private var scannedFood: Food?
    @State private var scannedFoodLogId: Int?
    
    // State for selected meal - initialized with time-based default
    @State private var selectedMeal: String = {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12:  // 5:00 AM to 11:59 AM
            return "Breakfast"
        case 12..<17:  // 12:00 PM to 4:59 PM
            return "Lunch"
        default:  // 5:00 PM to 4:59 AM
            return "Dinner"
        }
    }()

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            ZStack(alignment: .top) {
                // This rectangle acts as the top border
                Rectangle()
                    .frame(height: 0.5)
                    .foregroundColor(sharedViewModel.isItemViewActive ? Color(uiColor: UIColor.darkGray) : (colorScheme == .dark ? Color(uiColor: UIColor.darkGray) : Color(red: 0.9, green: 0.9, blue: 0.9)))
                    .zIndex(1)

                VStack(spacing: 12) {
                    // Food Scanning/Voice Input Bar (only show when NOT on profile tab)
                    if selectedTab != 4 {
                        HStack(spacing: 12) {
                            // Leading barcode icon
                            Button(action: {
                                HapticFeedback.generate()
                                showFoodScanner = true
                            }) {
                                Image(systemName: "barcode.viewfinder")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundColor(.primary)
                            }
                            
                            Spacer()
                            
                            // Center text
                            Text("Describe meal")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            // Trailing waveform icon
                            Button(action: {
                                HapticFeedback.generate()
                                showVoiceRecording = true
                            }) {
                                Image(systemName: "waveform")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundColor(.primary)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color("chatbar"))
                        .overlay(
                            RoundedRectangle(cornerRadius: 25)
                                .stroke(Color(.systemGray4), lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 25))
                        .padding(.horizontal, 16)
                    }
                    
                    // Tab Bar Icons
                    HStack {
                    
                       TabBarButton(iconName: "house", label: nil, isSelected: selectedTab == 0, iconSize: 17) { selectedTab = 0 }
                           .foregroundColor(selectedTab == 0 ? selectedIconColor : .gray)
                       
                       Spacer() 
                        
                        // TabBarButton(iconName: "folder", label: "Pods", isSelected: selectedTab == 2, iconSize: 16) { selectedTab = 2 }
                        //     .foregroundColor(selectedTab == 2 ? selectedIconColor : .gray)
                        
                        // Spacer() 

                        TabBarButton(iconName: "plus.app", isSelected: selectedTab == 1, iconSize: 20) {
                            HapticFeedback.generate()
                            showNewSheet = true
                        //    showQuickPodView = true
                        }
                        .foregroundColor(.primary)
                        // .offset(y: -5)
                        
                        Spacer() 

                    //    TabBarButton(iconName: "person.2", label: "Friends", isSelected: selectedTab == 3, iconSize: 16) { selectedTab = 3 }
                    //        .foregroundColor(selectedTab == 3 ? selectedIconColor : .gray)

                    //    Spacer() 

                        TabBarButton(iconName: "person", label: nil, isSelected: selectedTab == 4, iconSize: 17) { selectedTab = 4 }
                            .foregroundColor(selectedTab == 4 ? selectedIconColor : .gray)

                    }
                    .padding(.horizontal, 56)
                }
                .padding(.top, 11)
                // .background(Color(.systemBackground))
                    .background(Material.ultraThin)
            }
        }
        .fullScreenCover(isPresented: $showFoodScanner) {
            FoodScannerView(isPresented: $showFoodScanner, selectedMeal: selectedMeal, onFoodScanned: { food, foodLogId in
                // When a barcode is scanned and food is returned, show the confirmation view
                scannedFood = food
                scannedFoodLogId = foodLogId
                // Small delay to ensure transitions are smooth
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    showConfirmFoodView = true
                }
            })
            .edgesIgnoringSafeArea(.all)
        }
        .sheet(isPresented: $showVoiceRecording) {
            VoiceLogView(isPresented: $showVoiceRecording, selectedMeal: selectedMeal)
        }
        .sheet(isPresented: $showConfirmFoodView, onDismiss: {
            // Reset scanned food data
            scannedFood = nil
            scannedFoodLogId = nil
        }) {
            if let food = scannedFood {
                NavigationView {
                    ConfirmLogView(
                        path: .constant(NavigationPath()), // Dummy navigation path since we're using sheets
                        food: food,
                        foodLogId: scannedFoodLogId
                    )
                }
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
