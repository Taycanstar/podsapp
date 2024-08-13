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
    @State private var podTemplate: PodTemplate = .standard
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var viewModel: OnboardingViewModel
    var networkManager: NetworkManager = NetworkManager()
    @State private var errorMessage: String?
    @EnvironmentObject var uploadViewModel: UploadViewModel
    @EnvironmentObject var homeViewModel: HomeViewModel
    
    enum PodTemplate: String, CaseIterable {
        case standard = "Standard"
        case workout = "Workout"
        
        var id: Int {
            switch self {
            case .standard:
                return 0
            case .workout:
                return 1
            }
        }
        
        var displayText: String {
            switch self {
            case .standard:
                return "From scratch"
            case .workout:
                return "Workout"
            }
        }
    }

    var onPodCreated: (Pod) -> Void
    
    var body: some View {
        NavigationView {
            ZStack {
                (colorScheme == .dark ? Color(rgb: 44,44,44) : .white)
                    .edgesIgnoringSafeArea(.all)
                VStack(spacing: 20) {
                    // Pod Name Input
                    HStack {
                        TextField("Pod Name", text: $podName)
                    }
                    .padding()
                    .background(colorScheme == .dark ? Color(rgb: 44,44,44) : Color(rgb:244, 246, 247))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(borderColor, lineWidth: colorScheme == .dark ? 1 : 0)
                    )
                    .cornerRadius(10)
                    .padding(.horizontal)
                    .padding(.top)
                    
                    // Pod Mode Selection
                    HStack {
                        Image(systemName: "list.bullet")
                            .foregroundColor(.blue)
                        Text("Pod Template")
                        Spacer()
                        Picker("Pod Template", selection: $podTemplate) {
                            ForEach(PodTemplate.allCases, id: \.self) { template in
                                Text(template.displayText)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                    }
                    .padding()
                    .background(colorScheme == .dark ? Color(rgb: 44,44,44) : Color(rgb:244, 246, 247))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(borderColor, lineWidth: colorScheme == .dark ? 1 : 0)
                    )
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
        }
        .accentColor(.blue)
        .background(colorScheme == .dark ? Color.black : Color.white)
    }
    private var borderColor: Color {
        colorScheme == .dark ? Color(rgb: 86, 86, 86) : Color(rgb: 230, 230, 230)
    }
    private func createQuickPod() {
        guard !podName.isEmpty else {
            errorMessage = "Pod name is required."
            return
        }
        
        networkManager.createQuickPod(podTitle: podName, templateId: podTemplate.id, email: viewModel.email) { [self] success, podIdString in
            DispatchQueue.main.async {
                if success, let podIdString = podIdString, let podId = Int(podIdString) {
                    print("Quick Pod created successfully with ID: \(podId)")
                    let newPod = Pod(id: podId, items: [], title: self.podName , templateId: self.podTemplate.id)
                    print("New pod created with mode: \(newPod.templateId)")
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
