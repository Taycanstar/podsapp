//
//  ColorThemeView.swift
//  Pods
//
//  Created by Dimi Nunez on 5/19/24.
//

import SwiftUI

enum ThemeOption: String, CaseIterable {
    case light = "Light"
    case dark = "Dark"
    case system = "System"
}

class ThemeManager: ObservableObject {
    @AppStorage("selectedTheme") private var selectedTheme: String = ThemeOption.system.rawValue {
        didSet {
            updateTheme()
        }
    }
    
    @Published var currentTheme: ThemeOption = .system
    
    init() {
        currentTheme = ThemeOption(rawValue: selectedTheme) ?? .system
    }
    
    func updateTheme() {
        if let theme = ThemeOption(rawValue: selectedTheme) {
            currentTheme = theme
        }
    }
    
    func setTheme(_ theme: ThemeOption) {
        selectedTheme = theme.rawValue
    }
}

struct ColorThemeView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.colorScheme) var colorScheme
    var body: some View {
        ZStack {
            formBackgroundColor.edgesIgnoringSafeArea(.all)
            VStack {
                HStack {
                    Spacer()
                    themeOptionView(option: .light, imageName: "sun.max.fill")
                    Spacer()
                    themeOptionView(option: .dark, imageName: "moon.fill")
                    Spacer()
                }
                .padding()
                
                VStack(alignment: .leading) { // Align contents to the leading edge
                    Toggle(isOn: Binding(
                        get: { themeManager.currentTheme == .system },
                        set: { isOn in themeManager.setTheme(isOn ? .system : (themeManager.currentTheme == .dark ? .dark : .light)) }
                    )) {
                        Text("Use device settings")
                            .foregroundColor(colorScheme ==  .dark ? .white : .black)
                    }
                    .padding(.bottom, 2) // Add some spacing between the toggle and the text
                    
                    Text("Match appearance to your device’s Display & Brightness settings.")
                        .font(.footnote)
                        .foregroundColor(.gray)
                }
                .padding()
            }
            .background(colorScheme == .dark ? Color(rgb: 14, 14, 14) : Color(rgb: 242, 242, 242))
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle("Display")
            
        }
    }
    private var formBackgroundColor: Color {
           colorScheme == .dark ? Color(rgb: 14, 14, 14) : Color(rgb: 242, 242, 242)
       }

    private func themeOptionView(option: ThemeOption, imageName: String) -> some View {
        VStack {
            Image(systemName: imageName)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(height: 30) // Adjust this value to make the icon smaller
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(themeManager.currentTheme == option ? Color.blue : Color.clear, lineWidth: 2)
                )
            Text(option.rawValue)
                .font(.headline)
                .foregroundColor(colorScheme ==  .dark ? .white : .black)
        }
        .onTapGesture {
            themeManager.setTheme(option)
        }
    }
    
    private var iconColor: Color {
        themeManager.currentTheme == .dark ? .white : .black
    }
}


#Preview {
    ColorThemeView()
}
