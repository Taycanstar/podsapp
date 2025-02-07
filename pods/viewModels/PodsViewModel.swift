//
//  PodsViewModel.swift
//  Pods
//
//  Created by Dimi Nunez on 1/26/25.
//

import Foundation
import SwiftUI

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
    
     func cachePods(_ response: PodResponse) {
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
    

    
    func deletePod(podId: Int) {
        networkManager.deletePod(podId: podId) { [weak self] success, error in
            DispatchQueue.main.async {
                if success {
                    self?.pods.removeAll { $0.id == podId }
                    self?.updatePodsCache()
                } else if let error = error {
                    print("Failed to delete pod: \(error)")
                    self?.error = NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: error])
                }
            }
        }
    }
    
    func createFolder(name: String, email: String) {
        networkManager.createFolder(email: email, name: name) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let folder):
                    self?.folders.append(folder)
                    if let folders = self?.folders {
                        let response = FolderResponse(folders: folders)
                        self?.cacheFolders(response)
                    }
                case .failure(let error):
                    self?.error = error
                }
            }
        }
    }
    
    func deleteFolder(folderId: Int) {
        networkManager.deleteFolder(folderId: folderId) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self?.folders.removeAll { $0.id == folderId }
                    // Update cache with current folders
                    if let folders = self?.folders {
                        let response = FolderResponse(folders: folders)
                        self?.cacheFolders(response)
                    }
                case .failure(let error):
                    self?.error = error
                }
            }
        }
    }
    
    func updatePodsCache() {
        let podJSONs = pods.map { PodJSON(from: $0) }
        let response = PodResponse(folder: currentFolder, pods: podJSONs, totalPods: podJSONs.count)
        if let encoded = try? JSONEncoder().encode(response) {
            UserDefaults.standard.set(encoded, forKey: "pods_cache")
        }
    }

    func updatePodVisited(podId: Int) {
        networkManager.updatePodVisited(podId: podId) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    // Move pod to top of the list
                    if let index = self?.pods.firstIndex(where: { $0.id == podId }) {
                        if let pod = self?.pods.remove(at: index) {
                            self?.pods.insert(pod, at: 0)
                            // Update cache with new order
                            self?.updatePodsCache()
                        }
                    }
                case .failure(let error):
                    print("Failed to update pod visited time: \(error)")
                }
            }
        }
    }
    
    
    func updatePodsOrder(podIds: [Int]) {
        // Create a new array of pods in the correct order
        let orderedPods = podIds.compactMap { id in
            pods.first { $0.id == id }
        }
        
        // Update the pods array with the new order
        pods = orderedPods
        
        // Cache the new order
        let podJSONs = orderedPods.map { PodJSON(from: $0) }
        let response = PodResponse(folder: currentFolder, pods: podJSONs, totalPods: podJSONs.count)
        cachePods(response)
        
        // Update backend
        networkManager.updatePodsOrder(podIds: podIds) { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    print("Pod order updated successfully")
                case .failure(let error):
                    print("Failed to update pod order: \(error)")
                }
            }
        }
    }

}
