//
//  LogWorkoutView.swift
//  Pods
//
//  Created by Dimi Nunez on 6/5/25.
//

import SwiftUI

struct LogWorkoutView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedTab: Int
    @State private var searchText = ""
    @FocusState private var isSearchFieldFocused: Bool
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Background color for the entire view
            Color("iosbg2").edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 0) {
                // Main content
                VStack(spacing: 20) {
                    // Add Exercise section - styled like Quick Log button
                    Button(action: {
                        print("Tapped Add Exercise")
                        // TODO: Add exercise functionality
                    }) {
                        HStack(spacing: 6) {
                            Spacer()
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.accentColor)
                            Text("Add Exercise")
                                .font(.system(size: 17))
                                .fontWeight(.semibold)
                                .foregroundColor(.accentColor)
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color("iosfit"))
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)
                    .padding(.top, 0)
                    
                    Spacer()
                }
            }
            .edgesIgnoringSafeArea(.bottom)
            .searchable(
                text: $searchText,
                placement: .automatic,
                prompt: "Search Workouts"
            )
            .focused($isSearchFieldFocused)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
        }
        .navigationBarBackButtonHidden(true)
    }
    
    private var toolbarContent: some ToolbarContent {
        Group {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") {
                    selectedTab = 0
                    dismiss()
                }
                .foregroundColor(.accentColor)
            }
            
            ToolbarItem(placement: .principal) {
                Text("Log Workout")
                    .font(.headline)
            }
        }
    }
}

#Preview {
    NavigationView {
        LogWorkoutView(selectedTab: .constant(0))
    }
}
