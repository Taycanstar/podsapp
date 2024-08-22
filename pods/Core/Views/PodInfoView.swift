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
        @Binding var currentType: String
    let onSave: (String, String, String) -> Void
    @Environment(\.presentationMode) var presentationMode: Binding<PresentationMode>
    @Environment(\.isTabBarVisible) var isTabBarVisible
    @Environment(\.colorScheme) var colorScheme
    @State private var showPodTypeOptions = false
    @State private var selectedPodType: PodType
    @State private var podDetails: PodDetails?
      @State private var isLoading = true
      @State private var errorMessage: String?
    
    private var canEditPod: Bool {
        pod.role == "owner" || pod.role == "admin"
    }

    init(pod: Binding<Pod>,currentTitle: Binding<String>, currentDescription: Binding<String>, currentType: Binding<String>, onSave: @escaping (String, String, String) -> Void) {
        self._pod = pod
          self._currentTitle = currentTitle
          self._currentDescription = currentDescription
          self._currentType = currentType
          self.onSave = onSave
          self._selectedPodType = State(initialValue: PodType(rawValue: currentType.wrappedValue.lowercased()) ?? .main)
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
                    
                    // Workspace Section
                    Section(header: Text("Workspace").font(.system(size: 14))) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 15)
                                .fill(Color("mxdBg"))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(borderColor, lineWidth: 1)
                                )
                            
                            HStack {
                                DefaultProfilePicture(
                                    initial: podDetails?.workspace.profileInitial ?? "X",
                                    color: podDetails?.workspace.profileColor ?? "pink",
                                    size: 30
                                )
        
                                Text(podDetails?.workspace.name ?? "No name")
                                    .fontWeight(.medium)
                                    .font(.system(size: 14))
                                Spacer()
                            }
                            .padding()
                        }
                        .fixedSize(horizontal: false, vertical: true)
                    }

                    
                    Spacer()
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
        selectedPodType = PodType(rawValue: currentType.lowercased()) ?? .main
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
            type: currentType.lowercased()
        ) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let (updatedTitle, updatedDescription, updatedType)):
                    self.onSave(updatedTitle, updatedDescription, updatedType)
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

enum PodType: String, CaseIterable, Identifiable {
    case main = "Main"
    case shareable = "Shareable"
    case privateType = "Private"
    
    var id: String { self.rawValue }
    
    init?(rawValue: String) {
        switch rawValue.lowercased() {
        case "main": self = .main
        case "shareable": self = .shareable
        case "private": self = .privateType
        default: return nil
        }
    }
    
    var iconName: String {
        switch self {
        case .main: return "square.leadingthird.inset.filled"
        case .shareable: return "point.bottomleft.forward.to.point.topright.scurvepath.fill"
        case .privateType: return "lock"
        }
    }
    
    var description: String {
        switch self {
        case .main: return "Visible to your entire team"
        case .shareable: return "Share with guests outside your team"
        case .privateType: return "For working privately - alone or with selected members"
        }
    }
}
