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
    @EnvironmentObject var viewModel: OnboardingViewModel
    var networkManager: NetworkManager = NetworkManager()
    @State private var errorMessage: String?
    @EnvironmentObject var uploadViewModel: UploadViewModel
    @EnvironmentObject var homeViewModel: HomeViewModel
    
    enum PodMode: String, CaseIterable {
        case standard = "Standard"
        case workout = "Workout"
    }
    
    var onPodCreated: (Pod) -> Void
    
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
                        createQuickPod()
                    }
                    .disabled(podName.isEmpty)
                    .foregroundColor(podName.isEmpty ? .gray : .blue)
                }
            }
        }
        .accentColor(.blue)
        .background(colorScheme == .dark ? Color.black : Color.white)
    }
    private func createQuickPod() {
        guard !podName.isEmpty else {
            errorMessage = "Pod name is required."
            return
        }
        
        networkManager.createQuickPod(podTitle: podName, podMode: podMode.rawValue, email: viewModel.email) { [self] success, podIdString in
            DispatchQueue.main.async {
                if success, let podIdString = podIdString, let podId = Int(podIdString) {
                    print("Quick Pod created successfully with ID: \(podId)")
                    let newPod = Pod(id: podId, items: [], title: self.podName , mode: self.podMode.rawValue)
                    print("New pod created with mode: \(newPod.mode)")
                    self.homeViewModel.appendNewPod(newPod)
                    self.isPresented = false
                    self.onPodCreated(newPod)
                } else {
                    print("Failed to create quick pod: \(podIdString ?? "Unknown error")")
                    self.errorMessage = podIdString
                }
            }
        }
    }
}
