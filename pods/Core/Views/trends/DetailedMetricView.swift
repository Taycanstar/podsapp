//
//  DetailedMetricView.swift
//  Podstack
//
//  Created by Dimi Nunez on 10/11/24.
//
import SwiftUI

struct DetailedMetricView: View {
    let title: String
    let value: Double
    let unit: String
    let description: String
    let analysis: String
    @Environment(\.presentationMode) private var presentationMode
    
    @Environment(\.colorScheme) private var colorScheme
    

    
    var body: some View {
        VStack(spacing: 0) {
            glassomorphicHeader
               
            
            VStack(alignment: .leading, spacing: 20) {
                Text(description)
                    .font(.body)
                
//                VStack(alignment: .leading, spacing: 10) {
//                    Text("Analysis")
//                        .font(.title2)
//                        .fontWeight(.bold)
//                    
//                    Text(analysis)
//                        .font(.body)
//                }
            }
            .padding(.vertical, 25)
            .padding(.horizontal)
            
            Spacer()
        }
        .navigationBarTitle(title, displayMode: .inline)
        .navigationBarBackButtonHidden(true)

        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(colorScheme == .dark ? .white : Color.accentColor)
            }
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18))
                        .foregroundColor(colorScheme == .dark ? .white : Color.accentColor)
                }
            }
        }
        .edgesIgnoringSafeArea(.top)
    }
    
    private var glassomorphicHeader: some View {
        ZStack {
            backgroundEffect
            
            VStack(spacing: 10) {
                Spacer(minLength: 120)  // Adjust this value to fine-tune top spacing
                
                Text(String(format: "%.0f", value))
                    .foregroundColor(colorScheme == .dark ? .white : Color.accentColor)
                    .font(.system(size: 60, weight: .bold, design: .default))
                
                Text(unit)
                    .foregroundColor(colorScheme == .dark ? .white : Color.accentColor)
                    .font(.title3)
                    .fontWeight(.medium)
                
                Spacer(minLength: 15)  // Adjust this value to fine-tune bottom spacing
            }
            .foregroundColor(.white)
        }
        .frame(height: 270)
    }
    
    private var backgroundEffect: some View {
        ZStack {
            Color.accentColor
                .opacity(0.3)
                .blur(radius: 50)
            
            Rectangle()
                .fill(.ultraThinMaterial)
        }
    }
}


