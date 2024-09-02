//
//  SelectPodView.swift
//  Podstack
//
//  Created by Dimi Nunez on 8/16/24.
//

import SwiftUI

struct SelectPodView: View {
    @Binding var isPresented: Bool
    let currentPodId: Int
    let item: PodItem
    let onPodSelected: (Pod) -> Void
    @State private var pods: [Pod] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    let networkManager: NetworkManager
    let email: String

    var body: some View {
        NavigationView {
            Group {
                if isLoading {
                    ProgressView()
                } else if let error = errorMessage {
                    Text(error)
                } else {
                    List(pods.filter { $0.id != currentPodId }, id: \.id) { pod in
                        Button(action: {
                            onPodSelected(pod)
                            isPresented = false
                        }) {
                            Text(pod.title)
                        }
                    }
                }
            }
            .navigationTitle("Select Pod")
            .navigationBarItems(trailing: Button("Cancel") {
                isPresented = false
            })
        }
        .onAppear(perform: fetchPods)
    }
//
//    private func fetchPods() {
//        isLoading = true
//        networkManager.fetchPodsForUser(email: email) { success, fetchedPods, error in
//            isLoading = false
//            if success, let fetchedPods = fetchedPods {
//                self.pods = fetchedPods
//            } else {
//                self.errorMessage = error ?? "Failed to fetch pods"
//            }
//        }
//    }
    
    private func fetchPods() {
        isLoading = true
        networkManager.fetchPodsForUser(email: email) { [self] result in
            DispatchQueue.main.async {
                self.isLoading = false
                switch result {
                case .success(let fetchedPods):
                    self.pods = fetchedPods
                case .failure(let error):
                    // Handle error (you might want to show an alert here)
                    print("Failed to fetch pods: \(error)")
                }
            }
        }
    }
}
