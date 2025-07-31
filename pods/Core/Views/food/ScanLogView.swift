//
//  ScanLogView.swift
//  pods
//
//  Created by Dimi Nunez on 7/31/25.
//

import SwiftUI

struct ScanLogView: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.isTabBarVisible) var isTabBarVisible
    
    // State for toggle switches - default values as specified
    @State private var photoScanEnabled: Bool = false
    @State private var foodLabelEnabled: Bool = true
    @State private var barcodeEnabled: Bool = true
    @State private var galleryImportEnabled: Bool = false
    
    var body: some View {
        Form {
            Section(footer: Text("When Preview is enabled, you'll see nutrition details before logging. Turn it off for one-tap logging.")) {
                // Photo Scan row
                HStack {
                    Label("Photo Scan", systemImage: "camera")
                        .foregroundColor(iconColor)
                    Spacer()
                    Toggle("", isOn: $photoScanEnabled)
                        .labelsHidden()
                }
                .listRowBackground(rowBackgroundColor)
                
                // Food Label row
                HStack {
                    Label("Food Label", systemImage: "tag")
                        .foregroundColor(iconColor)
                    Spacer()
                    Toggle("", isOn: $foodLabelEnabled)
                        .labelsHidden()
                }
                .listRowBackground(rowBackgroundColor)
                
                // Barcode row
                HStack {
                    Label("Barcode", systemImage: "barcode.viewfinder")
                        .foregroundColor(iconColor)
                    Spacer()
                    Toggle("", isOn: $barcodeEnabled)
                        .labelsHidden()
                }
                .listRowBackground(rowBackgroundColor)
                
                // Gallery Import row
                HStack {
                    Label("Gallery Import", systemImage: "photo")
                        .foregroundColor(iconColor)
                    Spacer()
                    Toggle("", isOn: $galleryImportEnabled)
                        .labelsHidden()
                }
                .listRowBackground(rowBackgroundColor)
            }
        }
        .navigationTitle("Scan and Log Preview")
        .navigationBarTitleDisplayMode(.inline)
        .scrollContentBackground(.hidden)
        .background(formBackgroundColor.edgesIgnoringSafeArea(.all))
        .onAppear {
            isTabBarVisible.wrappedValue = false
        }
        .onDisappear {
            isTabBarVisible.wrappedValue = true
        }
    }
    
    // MARK: - Computed Properties
    
    private var iconColor: Color {
        colorScheme == .dark ? .white : .black
    }
    
    private var rowBackgroundColor: Color {
        colorScheme == .dark ? Color(rgb: 44, 44, 44) : .white
    }
    
    private var formBackgroundColor: Color {
        colorScheme == .dark ? Color(rgb: 14, 14, 14) : Color(rgb: 242, 242, 242)
    }
}

#Preview {
    NavigationView {
        ScanLogView()
    }
}