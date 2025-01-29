//
//  PodsViewModel.swift
//  Pods
//
//  Created by Dimi Nunez on 1/26/25.
//

import Foundation
import SwiftUI

//class PodsViewModel: ObservableObject {
//   @Published var pods: [Pod] = []
//   @Published var isLoading = false
//   private var networkManager = NetworkManager()
//
//   func fetchPods(email: String, completion: @escaping () -> Void) {
//       isLoading = true
//       networkManager.fetchPodsForUser2(email: email) { [weak self] data, error in
//           DispatchQueue.main.async {
//               if let pods = data {
//                   self?.pods = pods
//               } else if let error = error {
//                   print("Error fetching pods: \(error)")
//               }
//               self?.isLoading = false
//               completion()
//           }
//       }
//   }
//}

//class PodsViewModel: ObservableObject {
//    @Published var pods: [Pod] = []
//    @Published var isLoading = false
//    @Published var error: Error?
//    
//    private let networkManager = NetworkManager()
//    private var currentFolder: String = "Pods"
//    
//    func initialize(folder: String = "Pods", email: String) {
//        self.currentFolder = folder
//        loadCachedPods()
//        fetchPods(email: email)
//    }
//    
//    private func loadCachedPods() {
//        // Load from UserDefaults cache
//        if let cached = UserDefaults.standard.data(forKey: "pods_\(currentFolder)"),
//           let decodedResponse = try? JSONDecoder().decode(PodResponse.self, from: cached) {
//            self.pods = decodedResponse.pods.map { Pod(from: $0) }
//        }
//    }
//    
//    private func cachePods(_ response: PodResponse) {
//        if let encoded = try? JSONEncoder().encode(response) {
//            UserDefaults.standard.set(encoded, forKey: "pods_\(currentFolder)")
//        }
//    }
//    
//    func fetchPods(email: String) {
//        guard !isLoading else { return }
//        isLoading = true
//        
//        networkManager.fetchPodsForUser(email: email, folder: currentFolder) { [weak self] result in
//            DispatchQueue.main.async {
//                guard let self = self else { return }
//                self.isLoading = false
//                
//                switch result {
//                case .success(let response):
//                    self.pods = response.pods.map { Pod(from: $0) }
//                    self.cachePods(response)
//                case .failure(let error):
//                    self.error = error
//                }
//            }
//        }
//    }
//}
class PodsViewModel: ObservableObject {
    @Published var pods: [Pod] = []
    @Published var folders: [Folder] = []
    @Published var currentFolder: FolderData?
    @Published var isLoading = false
    @Published var error: Error?
    
    private let networkManager = NetworkManager()
    
    func initialize(email: String) {
        loadCachedData()
        fetchFolders(email: email)
        fetchPods(email: email)
    }
    
    private func loadCachedData() {
        // Load cached pods
        if let cached = UserDefaults.standard.data(forKey: "pods_cache"),
           let decodedResponse = try? JSONDecoder().decode(PodResponse.self, from: cached) {
            self.pods = decodedResponse.pods.map { Pod(from: $0) }
            self.currentFolder = decodedResponse.folder
        }
        
        // Load cached folders
        if let cached = UserDefaults.standard.data(forKey: "folders_cache"),
           let decodedResponse = try? JSONDecoder().decode(FolderResponse.self, from: cached) {
            self.folders = decodedResponse.folders
        }
    }
    
    private func cachePods(_ response: PodResponse) {
        if let encoded = try? JSONEncoder().encode(response) {
            UserDefaults.standard.set(encoded, forKey: "pods_cache")
        }
    }
    
    private func cacheFolders(_ response: FolderResponse) {
        if let encoded = try? JSONEncoder().encode(response) {
            UserDefaults.standard.set(encoded, forKey: "folders_cache")
        }
    }
    
    func fetchPods(email: String, folderName: String = "Pods") {
        guard !isLoading else { return }
        isLoading = true
        
        networkManager.fetchPodsForUser2(email: email, folderName: folderName) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isLoading = false
                
                switch result {
                case .success(let response):
                    self.pods = response.pods.map { Pod(from: $0) }
                    self.currentFolder = response.folder
                    self.cachePods(response)
                case .failure(let error):
                    self.error = error
                }
            }
        }
    }
    
    func fetchFolders(email: String) {
        networkManager.fetchUserFolders(email: email) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                switch result {
                case .success(let response):
                    self.folders = response.folders
                    self.cacheFolders(response)
                case .failure(let error):
                    self.error = error
                }
            }
        }
    }
}
