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
    
    // UserDefaults keys
    private let photoScanKey = "scanPreview_photoScan"
    private let foodLabelKey = "scanPreview_foodLabel"
    private let barcodeKey = "scanPreview_barcode"
    private let galleryImportKey = "scanPreview_galleryImport"
    
    // State for toggle switches - initialized from UserDefaults with fallback to defaults
    @State private var photoScanEnabled: Bool = UserDefaults.standard.object(forKey: "scanPreview_photoScan") as? Bool ?? true
    @State private var foodLabelEnabled: Bool = UserDefaults.standard.object(forKey: "scanPreview_foodLabel") as? Bool ?? true
    @State private var barcodeEnabled: Bool = UserDefaults.standard.object(forKey: "scanPreview_barcode") as? Bool ?? true
    @State private var galleryImportEnabled: Bool = UserDefaults.standard.object(forKey: "scanPreview_galleryImport") as? Bool ?? true
    
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
                        .onChange(of: photoScanEnabled) { newValue in
                            UserDefaults.standard.set(newValue, forKey: photoScanKey)
                        }
                }
                .listRowBackground(rowBackgroundColor)
                
                // Food Label row
                HStack {
                    Label("Food Label", systemImage: "tag")
                        .foregroundColor(iconColor)
                    Spacer()
                    Toggle("", isOn: $foodLabelEnabled)
                        .labelsHidden()
                        .onChange(of: foodLabelEnabled) { newValue in
                            UserDefaults.standard.set(newValue, forKey: foodLabelKey)
                        }
                }
                .listRowBackground(rowBackgroundColor)
                
                // Barcode row
                HStack {
                    Label("Barcode", systemImage: "barcode.viewfinder")
                        .foregroundColor(iconColor)
                    Spacer()
                    Toggle("", isOn: $barcodeEnabled)
                        .labelsHidden()
                        .onChange(of: barcodeEnabled) { newValue in
                            UserDefaults.standard.set(newValue, forKey: barcodeKey)
                        }
                }
                .listRowBackground(rowBackgroundColor)
                
                // Gallery Import row
                HStack {
                    Label("Gallery Import", systemImage: "photo")
                        .foregroundColor(iconColor)
                    Spacer()
                    Toggle("", isOn: $galleryImportEnabled)
                        .labelsHidden()
                        .onChange(of: galleryImportEnabled) { newValue in
                            UserDefaults.standard.set(newValue, forKey: galleryImportKey)
                        }
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
