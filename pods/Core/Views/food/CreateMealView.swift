//
//  CreateMealView.swift
//  Pods
//
//  Created by Dimi Nunez on 2/19/25.
//

import SwiftUI
import PhotosUI


import SwiftUI
import PhotosUI

struct CreateMealView: View {
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - State
    @State private var mealName = ""
    @State private var shareWith = "Everyone"
    @State private var instructions = ""
    @State private var showingShareOptions = false
    
    @State private var selectedItem: PhotosPickerItem? = nil
    @State private var selectedImage: Image? = nil
    @State private var showImagePicker = false
    @State private var showOptionsSheet = false
    @State private var sourceType: UIImagePickerController.SourceType = .camera
    
    // ADDED: These must exist in the parent if we reference them in Coordinator
    @State private var imageURL: URL? = nil
    @State private var uploadProgress: Double = 0
    @State private var isUploading = false
    @State private var uploadError: Error?
    @State private var showUploadError = false

    @State private var uiImage: UIImage? = nil


    // Example share options
    let shareOptions = ["Everyone", "Friends", "Only You"]
    
    // Adjust how tall you want the banner/collapsing area to be
    let headerHeight: CGFloat = 400
    
    // For demonstration
    private var macroPercentages: (protein: Double, carbs: Double, fat: Double) {
        (0, 0, 0)
    }
    
    var body: some View {
        GeometryReader { outerGeo in
            ScrollView(showsIndicators: false) {
                ZStack(alignment: .top) {
                    // A) Collapsing / Stretchy Header
                    GeometryReader { headerGeo in
                        let offset = headerGeo.frame(in: .global).minY
                        let height = offset > 0
                            ? (headerHeight + offset)
                            : headerHeight
                        
                        // The banner image (if selected), else a placeholder
                        if let selectedImage {
                            selectedImage
                                .resizable()
                                .scaledToFill()
                                .frame(width: outerGeo.size.width, height: height)
                                .clipped()
                                // Shift upward if scrolled up
                                .offset(y: offset > 0 ? -offset : 0)
                                .overlay(
                                    LinearGradient(
                                        gradient: Gradient(colors: [.clear, .black.opacity(0.3)]),
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .ignoresSafeArea(edges: .top)
                                .onTapGesture {
                                    showOptionsSheet = true
                                }
                        } else {
                            ZStack {
                                Color("iosnp")
                                Image(systemName: "camera.circle.fill")
                                    .font(.system(size: 40))
                                    .foregroundColor(.accentColor)
                            }
                            .frame(width: outerGeo.size.width, height: height)
                            .offset(y: offset > 0 ? -offset : 0)
                            .onTapGesture {
                                showOptionsSheet = true
                            }
                            .ignoresSafeArea(edges: .top)
                        }
                    }
                    .frame(height: headerHeight)
                    
                    // B) Main Scrollable Content
                    VStack(spacing: 16) {
                        Spacer().frame(height: headerHeight) // leave space for header
                        
                        mealDetailsSection
                        mealItemsSection
                        directionsSection
                        
                        Spacer().frame(height: 40) // extra bottom space
                    }
                }
            }
            .ignoresSafeArea(edges: .top)
        }
        // Transparent nav bar so we see banner behind it
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.clear, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("New Meal")
                    .foregroundColor(.primary)
                    .fontWeight(.semibold)
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Create") {
                    // Handle create action
                }
                .foregroundColor(.primary)
                .fontWeight(.semibold)
            }
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                        .foregroundColor(.primary)
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        
        // Full screen cover for ImagePicker
      .fullScreenCover(isPresented: $showImagePicker) {
    ImagePicker(
        uiImage: $uiImage,
        image: $selectedImage,
        sourceType: sourceType
    )
}
.onChange(of: uiImage) { newUIImage in
    guard let picked = newUIImage else { return }
    // Use your existing `uploadMealImage(_:, completion:)`
    // For example:
    NetworkManager().uploadMealImage(picked) { result in
        switch result {
        case .success(let url):
            print("Upload success. URL: \(url)")
            // store if needed, e.g. self.imageURL = url
        case .failure(let error):
            print("Upload failed:", error)
            // show alert if you like
        }
    }
}

        
        // Photo selection dialog
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
        // Add error alert
        .alert("Upload Error", isPresented: $showUploadError) {
            Button("Retry") {
                // implement retry if needed
            }
            Button("Cancel", role: .cancel) {
                uploadError = nil
            }
        } message: {
            Text(uploadError?.localizedDescription ?? "Unknown error")
        }
    }
    
    // MARK: - Subviews
    private var mealDetailsSection: some View {
        VStack(spacing: 16) {
            // Title
            TextField("Title", text: $mealName)
                .textFieldStyle(.plain)
                .padding(.vertical, 8)
            
            // Share-with row
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
            
            // Macros
            macroCircleAndStats
        }
        .padding()
        .background(Color("iosnp"))
        .cornerRadius(12)
        .padding(.horizontal)
    }
    
    private var mealItemsSection: some View {
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
    }
    
    private var directionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Directions")
                .font(.title2)
                .fontWeight(.bold)
            
            TextField("How to prepare...", text: $instructions, axis: .vertical)
                .textFieldStyle(.plain)
                .padding()
                .background(Color("iosnp"))
                .cornerRadius(12)
        }
        .padding(.horizontal)
        .padding(.bottom)
    }
    
    private var macroCircleAndStats: some View {
        HStack(spacing: 40) {
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 8)
                    .frame(width: 80, height: 80)
                
                Circle()
                    .trim(from: 0, to: CGFloat(macroPercentages.carbs) / 100)
                    .stroke(Color("teal"), style: StrokeStyle(lineWidth: 8, lineCap: .butt))
                    .frame(width: 80, height: 80)
                    .rotationEffect(.degrees(-90))
                
                Circle()
                    .trim(from: CGFloat(macroPercentages.carbs) / 100,
                          to: CGFloat(macroPercentages.carbs + macroPercentages.fat) / 100)
                    .stroke(Color("pinkRed"), style: StrokeStyle(lineWidth: 8, lineCap: .butt))
                    .frame(width: 80, height: 80)
                    .rotationEffect(.degrees(-90))
                
                Circle()
                    .trim(from: CGFloat(macroPercentages.carbs + macroPercentages.fat) / 100,
                          to: CGFloat(macroPercentages.carbs + macroPercentages.fat + macroPercentages.protein) / 100)
                    .stroke(Color("purple"), style: StrokeStyle(lineWidth: 8, lineCap: .butt))
                    .frame(width: 80, height: 80)
                    .rotationEffect(.degrees(-90))
                
                VStack(spacing: 0) {
                    Text("0").font(.system(size: 20, weight: .bold))
                    Text("Cal").font(.system(size: 14))
                }
            }
            
            Spacer()
            
            // Carbs
            MacroView(
                value: 0,
                percentage: macroPercentages.carbs,
                label: "Carbs",
                percentageColor: Color("teal")
            )
            
            // Fat
            MacroView(
                value: 0,
                percentage: macroPercentages.fat,
                label: "Fat",
                percentageColor: Color("pinkRed")
            )
            
            // Protein
            MacroView(
                value: 0,
                percentage: macroPercentages.protein,
                label: "Protein",
                percentageColor: .purple
            )
        }
    }
}


struct ImagePicker: UIViewControllerRepresentable {
    @Binding var uiImage: UIImage?
    @Binding var image: Image?
    
    let sourceType: UIImagePickerController.SourceType
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.allowsEditing = true
        picker.delegate = context.coordinator
        picker.modalPresentationStyle = .fullScreen
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject,
                       UIImagePickerControllerDelegate,
                       UINavigationControllerDelegate {
        let parent: ImagePicker
        init(_ parent: ImagePicker) { self.parent = parent }
        
        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]
        ) {
            if let uiImg = info[.editedImage] as? UIImage {
                // 1) Set raw UIImage
                parent.uiImage = uiImg
                // 2) Also set SwiftUI Image for display
                parent.image = Image(uiImage: uiImg)
            } else if let uiImg = info[.originalImage] as? UIImage {
                parent.uiImage = uiImg
                parent.image = Image(uiImage: uiImg)
            }
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}




// struct CreateMealView: View {
//     @Environment(\.dismiss) private var dismiss
    
//     // MARK: - State
//     @State private var mealName = ""
//     @State private var shareWith = "Everyone"
//     @State private var instructions = ""
//     @State private var showingShareOptions = false
    
//     @State private var selectedItem: PhotosPickerItem? = nil
//     @State private var selectedImage: Image? = nil
//     @State private var showImagePicker = false
//     @State private var showOptionsSheet = false
//     @State private var sourceType: UIImagePickerController.SourceType = .camera

//     @State private var uploadProgress: Double = 0
// @State private var isUploading = false
// @State private var uploadError: Error?
// @State private var showUploadError = false
    
//     // Example share options
//     let shareOptions = ["Everyone", "Friends", "Only You"]
    
//     // Adjust how tall you want the banner/collapsing area to be
//     let headerHeight: CGFloat = 400
    
//     // For demonstration
//     private var macroPercentages: (protein: Double, carbs: Double, fat: Double) {
//         (0, 0, 0)
//     }
    
//     var body: some View {
//         // 1) Outer GeometryReader to track screen size
//         GeometryReader { outerGeo in
//             ScrollView(showsIndicators: false) {
//                 // 2) A ZStack so the header + content overlap
//                 ZStack(alignment: .top) {
                    
//                     // A) Collapsing / Stretchy Header
//                     GeometryReader { headerGeo in
//                         let offset = headerGeo.frame(in: .global).minY
//                         let height = offset > 0
//                             ? (headerHeight + offset)   // stretch if pulled down
//                             : headerHeight              // normal or collapse
                        
//                         // The banner image (if selected), else a placeholder color
//                         if let selectedImage {
//                             selectedImage
//                                 .resizable()
//                                 .scaledToFill()
//                                 .frame(width: outerGeo.size.width,
//                                        height: height)
//                                 .clipped()
//                                 // Pin it to the top, shifting upward if scrolled up
//                                 .offset(y: offset > 0 ? -offset : 0)
//                                 .overlay(
//                                 //        if isUploading {
//                                 //     ProgressView("Uploading...", value: uploadProgress, total: 1.0)
//                                 //         .progressViewStyle(CircularProgressViewStyle(tint: .white))
//                                 //         .padding(20)
//                                 //         .background(Color.black.opacity(0.7))
//                                 //         .cornerRadius(10)
//                                 // }
//                                     LinearGradient(
//                                         gradient: Gradient(colors: [.clear, .black.opacity(0.3)]),
//                                         startPoint: .top,
//                                         endPoint: .bottom
//                                     )
//                                 )
//                                 .ignoresSafeArea(edges: .top)
//                                 .onTapGesture {  // Add this modifier
//                                     showOptionsSheet = true
//                                 }
//                         } else {
//                             ZStack {
//                                 Color("iosnp")
//                                 Image(systemName: "camera.circle.fill")
//                                     .font(.system(size: 40))
//                                     .foregroundColor(.accentColor)
//                             }
//                             .frame(width: outerGeo.size.width,
//                                    height: height)
//                             .offset(y: offset > 0 ? -offset : 0)
//                             .onTapGesture {
//                                 showOptionsSheet = true
//                             }
//                             .ignoresSafeArea(edges: .top)
//                         }
//                     }
//                     // Reserve the space for the header
//                     .frame(height: headerHeight)
                    
//                     // B) Main Scrollable Content
//                     VStack(spacing: 16) {
//                         // Leave empty space for the header
//                         Spacer().frame(height: headerHeight)
                        
//                         // Meal Details Card
//                         mealDetailsSection
                        
//                         // Meal Items Section
//                         mealItemsSection
                        
//                         // Directions Section
//                         directionsSection
                        
//                         // Extra space at bottom
//                         Spacer().frame(height: 40)
//                     }
//                 }
//             }
//             .ignoresSafeArea(edges: .top) // The scroll can go behind the top safe area
//         }
        
//         // 3) Transparent nav bar so we see banner behind it
//         .navigationBarTitleDisplayMode(.inline)
//         .toolbarBackground(.clear, for: .navigationBar)
//         .toolbar {
//             ToolbarItem(placement: .principal) {
//                 Text("New Meal")
//                     .foregroundColor(.primary)
//                     .fontWeight(.semibold)
//             }
//             ToolbarItem(placement: .navigationBarTrailing) {
//                 Button("Create") {
//                     // Handle create action
//                 }
//                 .foregroundColor(.primary)
//                 .fontWeight(.semibold)
//             }
//             ToolbarItem(placement: .navigationBarLeading) {
//                 Button(action: { dismiss() }) {
//                     Image(systemName: "chevron.left")
//                         .foregroundColor(.primary)
//                 }
//             }
//         }
//         .navigationBarBackButtonHidden(true)
        
//         // 4) Full screen cover for ImagePicker
//         .fullScreenCover(isPresented: $showImagePicker) {
//             ImagePicker(image: $selectedImage, sourceType: sourceType)
//                 .ignoresSafeArea()
//         }
        
//         // 5) Photo selection dialog
//         .confirmationDialog("Choose Photo", isPresented: $showOptionsSheet) {
//             Button("Take Photo") {
//                 sourceType = .camera
//                 showImagePicker = true
//             }
//             Button("Choose from Library") {
//                 sourceType = .photoLibrary
//                 showImagePicker = true
//             }
//             Button("Cancel", role: .cancel) {}
//         }
//         // Add error alert
// .alert("Upload Error", isPresented: $showUploadError) {
//     Button("Retry") {
//         // Implement retry logic if needed
//     }
//     Button("Cancel", role: .cancel) {
//         uploadError = nil
//     }
// } message: {
//     Text(uploadError?.localizedDescription ?? "Unknown error")
// }
//     }
    
//     // MARK: - Subviews
//     private var mealDetailsSection: some View {
//         VStack(spacing: 16) {
//             // Title
//             TextField("Title", text: $mealName)
//                 .textFieldStyle(.plain)
//                 .padding(.vertical, 8)
            
//             // Share-with row
//             HStack {
//                 Text("Share with")
//                     .foregroundColor(.primary)
//                 Spacer()
//                 Menu {
//                     ForEach(shareOptions, id: \.self) { option in
//                         Button(option) {
//                             shareWith = option
//                         }
//                     }
//                 } label: {
//                     HStack {
//                         Text(shareWith)
//                         Image(systemName: "chevron.up.chevron.down")
//                             .font(.system(size: 12))
//                     }
//                     .foregroundColor(.primary)
//                     .padding(.horizontal, 12)
//                     .padding(.vertical, 8)
//                     .background(Color("iosbtn"))
//                     .cornerRadius(8)
//                 }
//             }
            
//             // Macros
//             macroCircleAndStats
//         }
//         .padding()
//         .background(Color("iosnp"))
//         .cornerRadius(12)
//         .padding(.horizontal)
//     }
    
//     private var mealItemsSection: some View {
//         VStack(alignment: .leading, spacing: 12) {
//             Text("Meal Items")
//                 .font(.title2)
//                 .fontWeight(.bold)
            
//             Button {
//                 print("tapped items")
//             } label: {
//                 Text("Add item to meal")
//                     .foregroundColor(.accentColor)
//                     .frame(maxWidth: .infinity, alignment: .leading)
//                     .padding()
//                     .background(Color("iosnp"))
//                     .cornerRadius(12)
//             }
//         }
//         .padding(.horizontal)
//     }
    
//     private var directionsSection: some View {
//         VStack(alignment: .leading, spacing: 12) {
//             Text("Directions")
//                 .font(.title2)
//                 .fontWeight(.bold)
            
//             TextField("How to prepare...", text: $instructions, axis: .vertical)
//                 .textFieldStyle(.plain)
//                 .padding()
//                 .background(Color("iosnp"))
//                 .cornerRadius(12)
//         }
//         .padding(.horizontal)
//         .padding(.bottom)
//     }
    
//     private var macroCircleAndStats: some View {
//         HStack(spacing: 40) {
//             ZStack {
//                 // Background circle
//                 Circle()
//                     .stroke(Color.gray.opacity(0.2), lineWidth: 8)
//                     .frame(width: 80, height: 80)
                
//                 // Carbs segment
//                 Circle()
//                     .trim(from: 0, to: CGFloat(macroPercentages.carbs) / 100)
//                     .stroke(Color("teal"), style: StrokeStyle(lineWidth: 8, lineCap: .butt))
//                     .frame(width: 80, height: 80)
//                     .rotationEffect(.degrees(-90))
                
//                 // Fat segment
//                 Circle()
//                     .trim(from: CGFloat(macroPercentages.carbs) / 100,
//                           to: CGFloat(macroPercentages.carbs + macroPercentages.fat) / 100)
//                     .stroke(Color("pinkRed"), style: StrokeStyle(lineWidth: 8, lineCap: .butt))
//                     .frame(width: 80, height: 80)
//                     .rotationEffect(.degrees(-90))
                
//                 // Protein segment
//                 Circle()
//                     .trim(from: CGFloat(macroPercentages.carbs + macroPercentages.fat) / 100,
//                           to: CGFloat(macroPercentages.carbs + macroPercentages.fat + macroPercentages.protein) / 100)
//                     .stroke(Color("purple"), style: StrokeStyle(lineWidth: 8, lineCap: .butt))
//                     .frame(width: 80, height: 80)
//                     .rotationEffect(.degrees(-90))
                
//                 // Calories value in center
//                 VStack(spacing: 0) {
//                     Text("0")
//                         .font(.system(size: 20, weight: .bold))
//                     Text("Cal")
//                         .font(.system(size: 14))
//                 }
//             }
            
//             Spacer()
            
//             // Carbs
//             MacroView(
//                 value: 0,
//                 percentage: macroPercentages.carbs,
//                 label: "Carbs",
//                 percentageColor: Color("teal")
//             )
            
//             // Fat
//             MacroView(
//                 value: 0,
//                 percentage: macroPercentages.fat,
//                 label: "Fat",
//                 percentageColor: Color("pinkRed")
//             )
            
//             // Protein
//             MacroView(
//                 value: 0,
//                 percentage: macroPercentages.protein,
//                 label: "Protein",
//                 percentageColor: .purple
//             )
//         }
//     }
// }


// MARK: - ImagePicker for Photo Selection
// struct ImagePicker: UIViewControllerRepresentable {
//     @Binding var image: Image?
//     let sourceType: UIImagePickerController.SourceType
//     @Environment(\.dismiss) private var dismiss
    
//     func makeUIViewController(context: Context) -> UIImagePickerController {
//         let picker = UIImagePickerController()
//         picker.sourceType = sourceType
//         picker.delegate = context.coordinator
//         picker.modalPresentationStyle = .fullScreen
//         picker.allowsEditing = true
//         return picker
//     }
    
//     func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
//     func makeCoordinator() -> Coordinator {
//         Coordinator(self)
//     }
    
//     class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
//         let parent: ImagePicker
//         init(_ parent: ImagePicker) { self.parent = parent }
        
//         func imagePickerController(_ picker: UIImagePickerController,
//                                    didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
//             if let uiImage = info[.editedImage] as? UIImage {
//                 parent.image = Image(uiImage: uiImage)
//             }
//             parent.dismiss()
//         }
        
//         func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
//             parent.dismiss()
//         }
//     }
// }


