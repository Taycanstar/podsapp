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
                            .fontWeight(.bold)
//                            .padding()
                            .background(Color("mxdBg"))
                          
                    }
                    .padding(.top)
                    
                    Divider()
                    
                    // Pod Description Section
                    Section(header: Text("Pod Description").font(.system(size: 14))) {
                        TextField("Enter pod description", text: .constant(pod.description ?? ""))
                            .font(.system(size: 16))
                            .fontWeight(.bold)
//                            .padding()
                            .background(Color("mxdBg"))
                    }
                    
                    
                    Divider()
                    
                    // Pod Type Section
                    Section(header: Text("Pod Type").font(.headline)) {
                        Picker("Pod Type", selection: $pod.type) {
                            Text("Main").tag("main")
                            Text("Shareable").tag("shareable")
                            Text("Private").tag("private")
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .padding(.horizontal)
                    }
                    
                    Divider()
                    
                    // Created by Section
                    Section(header: Text("Created by").font(.headline)) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 15)
                                .fill(Color(UIColor.secondarySystemBackground))
                                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
                            
                            HStack {
        //                        DefaultProfilePicture(
        //                            initial: pod.user.profileInitial ?? "",
        //                            color: pod.user.profileColor ?? "",
        //                            size: 30
        //                        )
        //
        //                        Text(pod.user.name)
        //                            .fontWeight(.medium)
        //                            .font(.system(size: 14))
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
        //                        DefaultProfilePicture(
        //                            initial: pod.workspace?.profileInitial ?? "",
        //                            color: pod.workspace?.profileColor ?? "",
        //                            size: 30
        //                        )
        //
        //                        Text(pod.workspace?.name ?? "No Workspace")
        //                            .fontWeight(.medium)
        //                            .font(.system(size: 14))
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
              .navigationTitle("Pod Info")
              .navigationBarTitleDisplayMode(.inline)
              .onAppear {
                         isTabBarVisible.wrappedValue = false // Hide the TabBar when this view appears
                     }

          }
    
      }
