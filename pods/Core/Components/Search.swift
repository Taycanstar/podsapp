//
//  Search.swift
//  Pods
//
//  Created by Dimi Nunez on 12/6/24.
//

import SwiftUI
import Foundation


struct Search: View {
    @Binding var text: String
    var body: some View {
        VStack(spacing: 18){
            HStack(spacing: 5){
                Image(systemName: "magnifyingglass")
                    .foregroundColor(Color("nptext"))
                
                TextField("Search", text: $text)
                    .foregroundColor(Color("nptext"))
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 8)
            .background(Color("schbg"))
            .cornerRadius(12)
        }
    }
}

