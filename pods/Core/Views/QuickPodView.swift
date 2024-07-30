//
//  QuickPodView.swift
//  Podstack
//
//  Created by Dimi Nunez on 7/30/24.
//

import SwiftUI

struct QuickPodView: View {
    @Binding var isPresented: Bool
    @State private var podName: String = ""
    @State private var podMode: PodMode = .standard
    @Environment(\.colorScheme) var colorScheme
    
    enum PodMode: String, CaseIterable {
        case standard = "Standard"
        case workout = "Workout"
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Pod Name Input
                HStack {
                    TextField("Pod Name", text: $podName)
                }
                .padding()
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(10)
                .padding(.horizontal)
                .padding(.top)
                
                // Pod Mode Selection
                HStack {
                    Image(systemName: "list.bullet")
                        .foregroundColor(.blue)
                    Text("Pod Mode")
                    Spacer()
                    Picker("Pod Mode", selection: $podMode) {
                        ForEach(PodMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                }
                .padding()
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(10)
                .padding(.horizontal)
                
                Spacer()
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle("New Pod")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                    .foregroundColor(.blue)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        // Handle pod creation here
                        isPresented = false
                    }
                    .disabled(podName.isEmpty)
                    .foregroundColor(podName.isEmpty ? .gray : .blue)
                }
            }
        }
        .accentColor(.blue)
        .background(colorScheme == .dark ? Color.black : Color.white)
    }
}
