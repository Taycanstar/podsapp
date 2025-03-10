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
    @State private var podType: PodType = .custom
    @State private var podPrivacy: PodPrivacy = .only
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var viewModel: OnboardingViewModel
    var networkManager: NetworkManager = NetworkManager()
    @State private var errorMessage: String?
    @EnvironmentObject var uploadViewModel: UploadViewModel
    @EnvironmentObject var homeViewModel: HomeViewModel
    @EnvironmentObject var podsViewModel: PodsViewModel
    
    enum PodType: String, CaseIterable {
        case custom = "Custom"
        case workout = "Workout"
        case meal = "Meal"
        
        var id: Int {
            switch self {
            case .custom:
                return 0
            case .workout:
                return 1
            case .meal:
                return 2
            }
        }
        
        var displayText: String {
            switch self {
            case .custom:
                return "From scratch"
            case .workout:
                return "Workout"
            case .meal:
                return "Meal"
            }
        }
    }
    
    enum PodPrivacy: String, CaseIterable {
        case everyone = "public"
        case friends = "friends"
        case only = "private"
        
        var id: Int {
            switch self {
            case .everyone:
                return 0
            case .friends:
                return 1
            case .only:
                return 2
            }
        }
        
        var displayText: String {
            switch self {
            case .everyone:
                return "Everyone"
            case .friends:
                return "Friends"
            case .only:
                return "Only You"
            }
        }
    }

    var onPodCreated: (Pod) -> Void
    
    var body: some View {
        NavigationView {
            ZStack {
                (colorScheme == .dark ? Color(rgb: 44,44,44) : .white)
                    .edgesIgnoringSafeArea(.all)
                VStack(spacing: 16) {
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
                        Text("Type")
                        Spacer()
                        Picker("Type", selection: $podType) {
                            ForEach(PodType.allCases, id: \.self) { pType in
                                Text(pType.displayText)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                    }
                    .padding(10)
                    .background(colorScheme == .dark ? Color(rgb: 44,44,44) : Color(rgb:244, 246, 247))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(borderColor, lineWidth: colorScheme == .dark ? 1 : 0)
                    )
                    .cornerRadius(10)
                    .padding(.horizontal)
                    
                    // Pod privacy
                    HStack {
                        Image(systemName: "lock.fill")
                            .foregroundColor(.blue)
                        Text("Privacy")
                        Spacer()
                        Picker("Pod Privacy", selection: $podPrivacy) {
                            ForEach(PodPrivacy.allCases, id: \.self) { privacy in
                                Text(privacy.displayText)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                    }
                    .padding(10)
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
                        .fontWeight(.semibold)
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
            print("Pod name is empty")  // Debug
            errorMessage = "Pod name is required."
            return
        }
        
        print("Starting pod creation with name: \(podName)")  // Debug
        print("Type: \(podType.rawValue.lowercased())")      // Debug
        print("Privacy: \(podPrivacy.rawValue)")             // Debug
        print("Email: \(viewModel.email)")                   // Debug
        
        networkManager.createQuickPod(
            podTitle: podName,
            podType: podType.rawValue.lowercased(),
            privacy: podPrivacy.rawValue,
            email: viewModel.email
        ) { [self] result in
            print("Received API response")  // Debug
            DispatchQueue.main.async {
                switch result {
                case .success(let pod):
                    print("Successfully created pod with id: \(pod.id)")
                    podsViewModel.pods.append(pod)
                    podsViewModel.updatePodsCache()
                    onPodCreated(pod)
                    isPresented = false
                case .failure(let error):
                    print("Failed to create pod: \(error)")  // Debug
                    print("Error description: \(error.localizedDescription)")  // Debug
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}
