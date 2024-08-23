//
//  PodOptionsView.swift
//  Podstack
//
//  Created by Dimi Nunez on 8/4/24.
//

import SwiftUI

struct PodOptionsView: View {
    @Binding var showPodOptionsSheet: Bool
    @Binding var showPodColumnsView: Bool
    @Environment(\.dismiss) private var dismiss
    @State private var showDeleteConfirmation = false
    @State private var isSharePresented = false
    @State private var shareURL: URL?
     var onDeletePod: () -> Void
     var podName: String
    var podId: Int
    @EnvironmentObject var viewModel: OnboardingViewModel
    @Environment(\.colorScheme) var colorScheme
    var onPodInfoSelected: () -> Void
    var onPodMembersSelected: () -> Void
    
    @State private var shareItem: ActivityItem?
    var body: some View {
        ZStack {
            (colorScheme == .dark ? Color(rgb: 44,44,44) : .white)
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 0) {
                Capsule()
                    .fill(Color.secondary.opacity(0.6))
                    .frame(width: 35, height: 4)
                    .padding(.top, 10)
                
                HStack {
                    Spacer()
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 18))
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .foregroundColor(.primary)
                        
                    }
                }
                
                VStack(alignment: .leading, spacing: 0) {
                    MenuItemView(iconName: "square.and.arrow.up", text: "Share", action: {
                        print("Tapped Share")
//                        showPodOptionsSheet = false
                        generateShareLink()
                        HapticFeedback.generate()
                    }, color: .primary)
                    
                    MenuItemView(iconName: "info.circle", text: "Pod info", action: {
                        dismiss()
                        HapticFeedback.generate()
                       onPodInfoSelected()
                    }, color: .primary)
                    
                    MenuItemView(iconName: "person.2", text: "Pod members", action: {
                        dismiss()
                            print("Tapped pod members")
                        HapticFeedback.generate()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                             onPodMembersSelected()
                         }
                       
                    }, color: .primary)
                    
                    MenuItemView(iconName: "table", text: "Pod columns", action: {
                        dismiss()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            showPodColumnsView = true
                            print("tapped pod columns")
                        }
                        HapticFeedback.generate()
                    }, color: .primary)
                    
                    MenuItemView(iconName: "bubble", text: "Pod Chat", action: {
                        dismiss()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            print("Tapped Pod chat")
                        }
                        HapticFeedback.generate()
                    }, color: .primary)
                    
//                    MenuItemView(iconName: "bolt.horizontal.circle", text: "Activity Log", action: {
//                        dismiss()
//                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
//                            print("Tapped Pod activity")
//                        }
//                        HapticFeedback.generate()
//                    }, color: .primary)
                    //                
                    //                MenuItemView(iconName: "gauge.with.needle", text: "Progress Tracker", action: {
                    //                    dismiss()
                    //                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    //                        print("Tapped Progress")
                    //                    }
                    //                }, color: .primary)
                    
                    Divider().padding(.vertical, 5)
                    
                    MenuItemView(iconName: "trash", text: "Delete Pod", action: {
                        
                        showDeleteConfirmation = true
                        HapticFeedback.generate()
                        
                    }, color: .red)
                }
                .padding(.horizontal, 25)
                .padding(.top, 20)
                .padding(.bottom, 15)
                
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(colorScheme == .dark ? Color(rgb: 44,44,44) : .white)
            .cornerRadius(20)
            .confirmationDialog("Delete \"\(podName)\"? ",
                                isPresented: $showDeleteConfirmation,
                                titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    onDeletePod()
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            }
        }
        .sheet(isPresented: $isSharePresented, content: {
                    if let url = shareURL {
                        ActivityViewController(activityItems: [url])
                            .presentationDetents([.height(UIScreen.main.bounds.height / 2)])
                    }
                })
        
    }
    
    
    private func generateShareLink() {
        NetworkManager().sharePod(podId: podId, userEmail: viewModel.email) { result in
            switch result {
            case .success(let invitation):
                self.shareURL = URL(string: invitation.token)  // The token now contains the full shareUrl
                self.isSharePresented = true
            case .failure(let error):
                print("Failed to generate share link: \(error)")
            }
        }
    }
}

struct ActivityItem: Identifiable {
    let id = UUID()
    let items: [Any]
    let activities: [UIActivity]? = nil
}

struct ActivityViewController: UIViewControllerRepresentable {
    let activityItems: [Any]
    let applicationActivities: [UIActivity]? = nil

    func makeUIViewController(context: UIViewControllerRepresentableContext<ActivityViewController>) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: UIViewControllerRepresentableContext<ActivityViewController>) {}
}

struct MenuItemView: View {
    let iconName: String
    let text: String
    let action: () -> Void
    let color: Color

    var body: some View {
        Button(action: action) {
            HStack(spacing: 20) {
                Image(systemName: iconName)
                    .font(.system(size: 20))
                    .frame(width: 24, alignment: .center)  // Fixed width for all icons
                    .foregroundColor(color)
                
                Text(text)
                    .font(.system(size: 15))
                    .foregroundColor(color)
                
                Spacer()
            }
            .padding(.vertical, 17)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}
