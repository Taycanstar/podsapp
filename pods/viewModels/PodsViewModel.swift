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
   @Published var isLoading = false
   private var networkManager = NetworkManager()

   func fetchPods(email: String, completion: @escaping () -> Void) {
       isLoading = true
       networkManager.fetchPodsForUser2(email: email) { [weak self] data, error in
           DispatchQueue.main.async {
               if let pods = data {
                   self?.pods = pods
               } else if let error = error {
                   print("Error fetching pods: \(error)")
               }
               self?.isLoading = false
               completion()
           }
       }
   }
}
