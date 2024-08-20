//
//  PodInfoView.swift
//  Podstack
//
//  Created by Dimi Nunez on 8/19/24.
//

import SwiftUI

struct PodInfoView: View {
    @Binding var pod: Pod // Assuming you have a Pod model to pass as data
    @Environment(\.presentationMode) var presentationMode: Binding<PresentationMode>
    @Environment(\.isTabBarVisible) var isTabBarVisible
    @Environment(\.colorScheme) var colorScheme
    @State private var showPodTypeOptions = false
       @State private var selectedPodType: PodType = .main
    
    
    var body: some View {
        ZStack {
            Color("mxdBg")
                .edgesIgnoringSafeArea(.all)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Pod Name Section
                    Section(header: Text("Pod Name").font(.system(size: 14))) {
                        TextField("Enter Pod Name", text: $pod.title)
                            .font(.system(size: 16))
                            .fontWeight(.semibold)
                            .background(Color("mxdBg"))
                          
                    }
                    
                    Divider()
                    
                    // Pod Description Section
                    Section(header: Text("Pod Description").font(.system(size: 14))) {
                        TextField("Enter pod description", text: .constant(pod.description ?? ""))
                            .font(.system(size: 16))
                            .fontWeight(.semibold)
                            .background(Color("mxdBg"))
                    }
                    
                    
                    Divider()

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
                    .buttonStyle(PlainButtonStyle())
                    .padding(.vertical, 20)
//                    .padding(.horizontal, 15)
                    
                   
                    // Created by Section
                    Section(header: Text("Created by").font(.headline)) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 15)
                                .fill(Color(UIColor.secondarySystemBackground))
                                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
                            
                            HStack {
//                                DefaultProfilePicture(
//                                    initial: pod.user.profileInitial ?? "",
//                                    color: pod.user.profileColor ?? "",
//                                    size: 30
//                                )
//        
//                                Text(pod.user.name)
//                                    .fontWeight(.medium)
//                                    .font(.system(size: 14))
                                Spacer()
                            }
                            .padding()
                        }
                    }
                    .padding(.horizontal)
                    
                    Divider()
                    
                    // Workspace Section
                    Section(header: Text("Workspace").font(.headline)) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 15)
                                .fill(Color("container"))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 15)
                                        .fill(Color.accentColor.opacity(0.15))
                                )
                            
                            HStack {
//                                DefaultProfilePicture(
//                                    initial: pod.workspace?.profileInitial ?? "",
//                                    color: pod.workspace?.profileColor ?? "",
//                                    size: 30
//                                )
//        
//                                Text(pod.workspace?.name ?? "No Workspace")
//                                    .fontWeight(.medium)
//                                    .font(.system(size: 14))
                                Spacer()
                            }
                            .padding()
                        }
                        .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal)
                    
                    Spacer()
                }
                .padding()
                  }
              }
        .navigationBarItems(
            trailing: Button(action: {
                presentationMode.wrappedValue.dismiss()            }) {
                Text("Save")
                    .foregroundColor(.accentColor)
            }
        )
              .navigationTitle("Pod info")
              .navigationBarTitleDisplayMode(.inline)
              .onAppear {
                         isTabBarVisible.wrappedValue = false
                  updateSelectedPodType()

                  
                  print("pod type", pod.type)
                     }
              .sheet(isPresented: $showPodTypeOptions) {
                         PodTypeOptions(selectedType: $selectedPodType, isPresented: $showPodTypeOptions)
                      .presentationDetents([.height(UIScreen.main.bounds.height / 3)])
                     }
        
              .onChange(of: selectedPodType) { oldValue, newValue in
                  updatePodType()
              }

          }
    
    private func updateSelectedPodType() {
        if let podType = pod.type {
            selectedPodType = PodType(rawValue: podType.lowercased()) ?? .main
        } else {
            selectedPodType = .main
        }
        print("Updated selectedPodType to: \(selectedPodType.rawValue)")
    }
    
    private func updatePodType() {
        pod.type = selectedPodType.rawValue.lowercased()
        print("Updated pod.type to: \(pod.type ?? "nil")")
    }
    
    private func savePodChanges() {
            // Implement the logic to save pod changes
            // This might involve calling an API or updating a database
            print("Saving pod changes. Type: \(pod.type ?? "nil")")
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
