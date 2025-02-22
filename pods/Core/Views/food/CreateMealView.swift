//
//  CreateMealView.swift
//  Pods
//
//  Created by Dimi Nunez on 2/19/25.
//

import SwiftUI
import PhotosUI

struct CreateMealView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var mealName = ""
    @State private var shareWith = "Everyone"
    @State private var instructions = ""
    @State private var showingShareOptions = false
    @State private var selectedItem: PhotosPickerItem? = nil
    @State private var selectedImage: Image? = nil
    @State private var showImagePicker = false
    @State private var showOptionsSheet = false
    @State private var sourceType: UIImagePickerController.SourceType = .camera
    
    let shareOptions = ["Everyone", "Friends", "Only You"]
    
    private var macroPercentages: (protein: Double, carbs: Double, fat: Double) {
        // For now returning 0s since it's a new meal
        return (0, 0, 0)
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Camera Icon Card
                Button {
                    // Show options sheet first instead of going directly to camera
                    showOptionsSheet = true
                } label: {
                    ZStack {
                        Color("iosnp")
                        if let selectedImage {
                            selectedImage
                                .resizable()
                                .scaledToFill()
                        } else {
                            Image(systemName: "camera.circle.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.accentColor)
                        }
                    }
                    .frame(width: 100, height: 100)
                    .cornerRadius(12)
                    .clipped()
                }
                .fullScreenCover(isPresented: $showImagePicker) {
                    ImagePicker(image: $selectedImage, sourceType: sourceType)
                        .ignoresSafeArea() // Make picker full screen
                }
                .confirmationDialog("Choose Photo", isPresented: $showOptionsSheet) {
                    Button("Take Photo") {
                        sourceType = .camera
                        showImagePicker = true
                    }
                    Button("Choose from Library") {
                        sourceType = .photoLibrary
                        showImagePicker = true
                    }
                    Button("Cancel", role: .cancel) {}
                }
                
                // Meal Details Card
                VStack(spacing: 16) {
                    TextField("Title", text: $mealName)
                        .textFieldStyle(.plain)  // Remove the border style
                        .padding(.vertical, 8)   // Add some vertical padding
                    
                    HStack {
                        Text("Share with")
                            .foregroundColor(.primary)
                        Spacer()
                        Menu {
                            ForEach(shareOptions, id: \.self) { option in
                                Button(option) {
                                    shareWith = option
                                }
                            }
                        } label: {
                            HStack {
                                Text(shareWith)
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.system(size: 12))
                            }
                            .foregroundColor(.primary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color("iosbtn"))
                            .cornerRadius(8)
                        }
                    }
                    
                    // Macros section with circular progress
                    HStack(spacing: 40) {
                        ZStack {
                            // Background circle
                            Circle()
                                .stroke(Color.gray.opacity(0.2), lineWidth: 8)
                                .frame(width: 80, height: 80)
                            
                            // Carbs segment
                            Circle()
                                .trim(from: 0, to: CGFloat(macroPercentages.carbs) / 100)
                                .stroke(Color("teal"), style: StrokeStyle(lineWidth: 8, lineCap: .butt))
                                .frame(width: 80, height: 80)
                                .rotationEffect(.degrees(-90))
                            
                            // Fat segment
                            Circle()
                                .trim(from: CGFloat(macroPercentages.carbs) / 100,
                                    to: CGFloat(macroPercentages.carbs + macroPercentages.fat) / 100)
                                .stroke(Color("pinkRed"), style: StrokeStyle(lineWidth: 8, lineCap: .butt))
                                .frame(width: 80, height: 80)
                                .rotationEffect(.degrees(-90))
                            
                            // Protein segment
                            Circle()
                                .trim(from: CGFloat(macroPercentages.carbs + macroPercentages.fat) / 100,
                                    to: CGFloat(macroPercentages.carbs + macroPercentages.fat + macroPercentages.protein) / 100)
                                .stroke(Color("purple"), style: StrokeStyle(lineWidth: 8, lineCap: .butt))
                                .frame(width: 80, height: 80)
                                .rotationEffect(.degrees(-90))
                            
                            // Calories value in center
                            VStack(spacing: 0) {
                                Text("0")
                                    .font(.system(size: 20, weight: .bold))
                                Text("Cal")
                                    .font(.system(size: 14))
                            }
                        }
                        
                        Spacer()
                        
                        // Macros
                        MacroView(
                            value: 0,
                            percentage: macroPercentages.carbs,
                            label: "Carbs",
                            percentageColor: Color("teal")
                        )
                        
                        MacroView(
                            value: 0,
                            percentage: macroPercentages.fat,
                            label: "Fat",
                            percentageColor: Color("pinkRed")
                        )
                        
                        MacroView(
                            value: 0,
                            percentage: macroPercentages.protein,
                            label: "Protein",
                            percentageColor: .purple
                        )
                    }
                }
                .padding()
                .background(Color("iosnp"))
                .cornerRadius(12)
                .padding(.horizontal)  // Add horizontal padding to the entire card
                
                // Meal Items Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Meal Items")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Button {
                        print("tapped items")
                    } label: {
                        Text("Add item to meal")
                            .foregroundColor(.accentColor)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(Color("iosnp"))
                            .cornerRadius(12)
                    }
                }
                .padding(.horizontal)
                
                // Directions Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Directions")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    TextField("", text: $instructions, axis: .vertical)
                        .textFieldStyle(.plain)
                        .padding()
                        .background(Color("iosnp"))
                        .cornerRadius(12)
                }
                .padding(.horizontal)
                .padding(.bottom)
                .transition(.opacity)
            }
            .padding(.vertical)
        }
        .background(Color("iosbg").ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            
            ToolbarItem(placement: .principal) {
                Text("New Meal")
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Create") {
                    // Handle create action
                }
                .foregroundColor(.accentColor)
            }
        }
    }
}


// Add this helper view for UIImagePickerController
struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: Image?
    let sourceType: UIImagePickerController.SourceType
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        // Make it full screen
        picker.modalPresentationStyle = .fullScreen
        return picker
    }
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let uiImage = info[.originalImage] as? UIImage {
                parent.image = Image(uiImage: uiImage)
            }
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}