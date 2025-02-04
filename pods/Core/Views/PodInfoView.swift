//
//  PodInfoView.swift
//  Podstack
//
//  Created by Dimi Nunez on 8/19/24.
//

import SwiftUI

struct PodInfoView: View {
    @Binding var pod: Pod
    @Binding var currentTitle: String
    @Binding var currentDescription: String
    @Binding var currentInstructions: String
    @Binding var currentType: String
    @Binding var currentPrivacy: String
    let onSave: (String, String, String, String) -> Void
    @Environment(\.presentationMode) var presentationMode: Binding<PresentationMode>
    @Environment(\.isTabBarVisible) var isTabBarVisible
    @Environment(\.colorScheme) var colorScheme
    @State private var showPodTypeOptions = false
    @State private var showPodPrivacyOptions = false
    @State private var selectedPodType: PodType
    @State private var selectedPodPrivacy: PodPrivacy
    @State private var podDetails: PodDetails?
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    private var canEditPod: Bool {
        pod.role == "owner" || pod.role == "admin"
    }
    
    init(pod: Binding<Pod>,currentTitle: Binding<String>, currentDescription: Binding<String>, currentType: Binding<String>, currentPrivacy: Binding<String>, currentInstructions: Binding<String>, onSave: @escaping (String, String, String, String) -> Void) {
        self._pod = pod
        self._currentTitle = currentTitle
        self._currentDescription = currentDescription
        self._currentInstructions = currentInstructions
        self._currentType = currentType
        self._currentPrivacy = currentPrivacy
        self.onSave = onSave
        self._selectedPodType = State(initialValue: PodType(rawValue: currentType.wrappedValue.lowercased()) ?? .custom)
        self._selectedPodPrivacy = State(initialValue: PodPrivacy(rawValue: currentType.wrappedValue.lowercased()) ?? .only)
    }
    
    
    var body: some View {
        ZStack {
            Color("mxdBg")
                .edgesIgnoringSafeArea(.all)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Pod Name Section
                    Section(header: Text("Pod Name").font(.system(size: 14))) {
                        TextField("Enter Pod Name", text: $currentTitle)
                            .font(.system(size: 16))
                            .fontWeight(.semibold)
                            .background(Color("mxdBg"))
                            .disabled(!canEditPod)
                        
                    }
                    
                    Divider()
                        .background(borderColor)
                    
                    // Pod Description Section
                    Section(header: Text("Pod Description").font(.system(size: 14))) {
                        TextField("Enter pod description", text: $currentDescription)
                            .font(.system(size: 16))
                            .fontWeight(.semibold)
                            .background(Color("mxdBg"))
                            .disabled(!canEditPod)
                    }
                    
                    
                    Divider()
                        .background(borderColor)
                    
                    //                    VStack(alignment: .leading, spacing: 20) {
                    //                        // Pod Instructions Section
                    //                        Section(header: Text("Custom Pod instructions").font(.system(size: 14))) {
                    //                            ZStack {
                    //                                // Background with desired color and rounded corners
                    //                                RoundedRectangle(cornerRadius: 10)
                    //                                    .fill(Color("mxdBg"))
                    //                                    .overlay(
                    //                                        RoundedRectangle(cornerRadius: 10)
                    //                                            .stroke(borderColor, lineWidth: 1)
                    //                                    )
                    //
                    //                                // TextEditor with transparent background
                    //                                TextEditor(text: $currentInstructions)
                    //                                    .padding(8) // Adjust padding as needed
                    //                                    .font(.system(size: 16))
                    //                                    .fontWeight(.semibold)
                    //                                    .frame(minHeight: 100)  // Provide minimum height for better usability
                    //                                    .foregroundColor(.primary)
                    //                                    .scrollContentBackground(.hidden) // Hide the default background
                    //                                    .disabled(!canEditPod)
                    //                            }
                    //                            .padding(.horizontal, -4)  // Adjust if necessary
                    //                        }
                    //                    }
                    
                    
                    Divider()
                        .background(borderColor)
                    
                    Button(action: {
                        print("tapped pod type")
                        showPodTypeOptions = true
                    }, label: {
                        HStack {
                            Image(systemName: selectedPodType.iconName)
                                .foregroundColor(.primary)
                            
                            VStack(alignment: .leading){
                                Text("Pod Type")
                                    .font(.system(size: 12))
                                    .foregroundColor(.primary)
                                Text(selectedPodType.rawValue)
                                    .font(.system(size: 14))
                                    .foregroundColor(.primary)
                            }
                            .padding(.horizontal, 10)
                            Spacer()
                            
                            Image(systemName: showPodTypeOptions ? "chevron.up" : "chevron.down")
                                .foregroundColor(.primary)
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 10)
                        .cornerRadius(15)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(borderColor, lineWidth: 1)
                        )
                    })
                    .disabled(!canEditPod)
                    
                    
                    Button(action: {
                        print("tapped pod Privacy")
                        showPodPrivacyOptions = true
                    }, label: {
                        HStack {
                            Image(systemName:"lock.fill")
                                .foregroundColor(.primary)
                            VStack(alignment: .leading){
                                Text("Pod Privacy")
                                    .font(.system(size: 12))
                                    .foregroundColor(.primary)
                                Text(selectedPodPrivacy.rawValue)
                                    .font(.system(size: 14))
                                    .foregroundColor(.primary)
                            }
                            .padding(.horizontal, 10)
                            Spacer()
                            
                            Image(systemName: showPodPrivacyOptions ? "chevron.up" : "chevron.down")
                                .foregroundColor(.primary)
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 10)
                        .cornerRadius(15)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(borderColor, lineWidth: 1)
                        )
                    })
                    .disabled(!canEditPod)
                    
                    .buttonStyle(PlainButtonStyle())
                    .padding(.vertical, 20)
                    //                    .padding(.horizontal, 15)
                    
                    
                    // Created by Section
                    Section(header: Text("Created by").font(.system(size: 14))) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 15)
                                .fill(Color("mxdBg"))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(borderColor, lineWidth: 1)
                                )
                            
                            
                            HStack {
                                DefaultProfilePicture(
                                    initial: podDetails?.creator.profileInitial ?? "Y",
                                    color: podDetails?.creator.profileColor ?? "blue",
                                    size: 30
                                )
                                
                                Text(podDetails?.creator.name ?? "No creator")
                                    .fontWeight(.medium)
                                    .font(.system(size: 14))
                                Spacer()
                            }
                            .padding()
                        }
                    }
                    
                    
                    Divider()
                        .background(borderColor)
//                    
//                     Workspace Section
//                                        Section(header: Text("Workspace").font(.system(size: 14))) {
//                                            ZStack {
//                                                RoundedRectangle(cornerRadius: 15)
//                                                    .fill(Color("mxdBg"))
//                                                    .overlay(
//                                                        RoundedRectangle(cornerRadius: 10)
//                                                            .stroke(borderColor, lineWidth: 1)
//                                                    )
//                    
//                                                HStack {
//                                                    DefaultProfilePicture(
//                                                        initial: podDetails?.workspace.profileInitial ?? "X",
//                                                        color: podDetails?.workspace.profileColor ?? "pink",
//                                                        size: 30
//                                                    )
//                    
//                                                    Text(podDetails?.workspace.name ?? "No name")
//                                                        .fontWeight(.medium)
//                                                        .font(.system(size: 14))
//                                                    Spacer()
//                                                }
//                                                .padding()
//                                            }
//                                            .fixedSize(horizontal: false, vertical: true)
//                                        }
                    
                    
//                                        Spacer()
                                    }
                                    .padding()
                }
            }
            .navigationBarItems(
                trailing: Button(action: {
                    savePodChanges()
                    presentationMode.wrappedValue.dismiss()
                    
                }) {
                    Text("Save")
                        .foregroundColor(.accentColor)
                }
                    .disabled(!canEditPod)
                    .opacity(canEditPod ? 1 : 0)
            )
            .navigationTitle("Pod info")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                isTabBarVisible.wrappedValue = false
                updateSelectedPodType()
                loadPodDetails()
                
                
            }
            .sheet(isPresented: $showPodTypeOptions) {
                PodTypeOptions(selectedType: $selectedPodType, isPresented: $showPodTypeOptions)
                    .presentationDetents([.height(UIScreen.main.bounds.height / 3)])
            }
            .sheet(isPresented: $showPodPrivacyOptions) {
                PodPrivacyOptions(selectedPrivacy: $selectedPodPrivacy, isPresented: $showPodPrivacyOptions)
                    .presentationDetents([.height(UIScreen.main.bounds.height / 3)])
            }
            
            .onChange(of: selectedPodType) { oldValue, newValue in
                updatePodType()
            }
            
        }
        
        private func loadPodDetails() {
            isLoading = true
            NetworkManager().fetchPodDetails(podId: pod.id) { result in
                DispatchQueue.main.async {
                    isLoading = false
                    switch result {
                    case .success(let details):
                        self.podDetails = details
                    case .failure(let error):
                        self.errorMessage = error.localizedDescription
                    }
                }
            }
        }
        
        private func updateSelectedPodType() {
            selectedPodType = PodType(rawValue: currentType.lowercased()) ?? .custom
            print("Updated selectedPodType to: \(selectedPodType.rawValue)")
        }
        
        private func updatePodType() {
            currentType = selectedPodType.rawValue
        }
        
        
        private func savePodChanges() {
            NetworkManager().updatePodDetails(
                podId: pod.id,
                title: currentTitle,
                description: currentDescription,
                instructions: currentInstructions,
                type: currentType.lowercased()
            ) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let (updatedTitle, updatedDescription, updatedInstructions, updatedType)):
                        self.onSave(updatedTitle, updatedDescription, updatedInstructions, updatedType)
                        self.presentationMode.wrappedValue.dismiss()
                    case .failure(let error):
                        print("Failed to update pod: \(error)")
                    }
                }
            }
        }
        
        private var borderColor: Color {
            colorScheme == .dark ? Color(rgb: 71, 71, 71) : Color(rgb: 219, 223, 236)
        }
        
    }
    
    
    
    struct PodTypeOptions: View {
        @Binding var selectedType: PodType
        @Binding var isPresented: Bool
        @Environment(\.presentationMode) var presentationMode
        
        var body: some View {
            NavigationView {
                List(PodType.allCases) { type in
                    Button(action: {
                        selectedType = type
                        isPresented = false
                    }) {
                        HStack {
                            Image(systemName: selectedType == type ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(selectedType == type ? .accentColor : .gray)
                            
                            VStack(alignment: .leading, spacing: 5) {
                                HStack {
                                    Image(systemName: type.iconName)
                                    Text(type.rawValue)
                                        .font(.headline)
                                }
                                Text(type.description)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                .listStyle(PlainListStyle())
                .navigationBarItems(
                    leading: Button(action: {
                        isPresented = false
                    }) {
                        Image(systemName: "xmark")
                            .foregroundColor(.primary)
                    }
                )
                .navigationBarTitle("Pod Type", displayMode: .inline)
            }
        }
    }


struct PodPrivacyOptions: View {
    @Binding var selectedPrivacy: PodPrivacy
    @Binding var isPresented: Bool
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            List(PodPrivacy.allCases) { type in
                Button(action: {
                    selectedPrivacy = type
                    isPresented = false
                }) {
                    HStack {
                        Image(systemName: selectedPrivacy == type ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(selectedPrivacy == type ? .accentColor : .gray)
                        
                        VStack(alignment: .leading, spacing: 5) {
                            HStack {
                        
                                Text(type.rawValue)
                                    .font(.headline)
                            }
                            Text(type.description)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .listStyle(PlainListStyle())
            .navigationBarItems(
                leading: Button(action: {
                    isPresented = false
                }) {
                    Image(systemName: "xmark")
                        .foregroundColor(.primary)
                }
            )
            .navigationBarTitle("Pod Privacy", displayMode: .inline)
        }
    }
}
    
    enum PodType: String, CaseIterable, Identifiable {
        case custom = "Custom"
        case workout = "Workout"
        case meal = "Meal"
        
        var id: String { self.rawValue }
        
        init?(rawValue: String) {
            switch rawValue.lowercased() {
            case "custom": self = .custom
            case "workout": self = .workout
            case "meal": self = .meal
            default: return nil
            }
        }
        
        var iconName: String {
            switch self {
            case .custom: return "square.leadingthird.inset.filled"
            case .workout: return "figure.run"
            case .meal: return "fork.knife"
            }
        }
        
        var description: String {
            switch self {
            case .custom: return "Build your own pod from scratch with no presets."
            case .workout: return "Includes set, weight, and reps as grouped columns."
            case .meal: return "Predefined columns for quantity, carbs, protein, and more."
            }
        }
    }
    
    
    enum PodPrivacy: String, CaseIterable, Identifiable {
        case everyone = "Everyone"
        case friends = "Friends"
        case only = "Only You"
        
        var id: String { self.rawValue }
        
        init?(rawValue: String) {
            switch rawValue.lowercased() {
            case "everyone": self = .everyone
            case "friends": self = .friends
            case "only": self = .only
            default: return nil
            }
        }
        
        
        
        var description: String {
            switch self {
            case .everyone: return "Visible to all users."
            case .friends: return "Followers you follow back."
            case .only: return "Predefined columns for quantity, carbs, fat, and more."
            }
        }
    }
    

