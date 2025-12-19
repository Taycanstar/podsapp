//
//  ImportRecipeSheet.swift
//  pods
//
//  Created by Dimi Nunez on 12/18/25.
//


//
//  ImportRecipeSheet.swift
//  pods
//
//  Created by Dimi Nunez on 12/18/25.
//

import SwiftUI

struct ImportRecipeSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject var foodManager: FoodManager

    // Form inputs
    @State private var recipeURL = ""

    // UI state
    @State private var isImporting = false
    @State private var errorMessage: String?
    @State private var importedRecipe: Recipe?

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Input form
                urlInputRow
                    .padding(.horizontal)
                    .padding(.top, 20)

                // Helper text
                Text("Paste a URL from any recipe website. We'll automatically extract the recipe details.")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.top, 12)

                // Error message
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .font(.system(size: 14))
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                        .padding(.top, 12)
                }

                // Loading indicator
                if isImporting {
                    VStack(spacing: 12) {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text("Analyzing recipe...")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 40)
                }

                Spacer()

                // Footer with import button
                footerBar
            }
            .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Import Recipe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.primary)
                    }
                }
            }
        }
    }

    // MARK: - URL Input Row

    private var urlInputRow: some View {
        TextField("URL", text: $recipeURL)
            .keyboardType(.URL)
            .textContentType(.URL)
            .autocapitalization(.none)
            .autocorrectionDisabled()
            .font(.system(size: 17))
            .foregroundColor(.primary)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .clipShape(Capsule())
    }

    // MARK: - Footer Bar

    private var footerBar: some View {
        VStack(spacing: 16) {
            Divider()
                .padding(.horizontal, -16)

            Button(action: {
                HapticFeedback.generateLigth()
                importRecipe()
            }) {
                Text(isImporting ? "Importing..." : "Import")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            }
            .buttonStyle(.plain)
            .background(
                RoundedRectangle(cornerRadius: 999, style: .continuous)
                    .fill(isValidURL ? Color("background") : Color(.systemGray5))
            )
            .foregroundColor(isValidURL ? Color("text") : Color(.systemGray))
            .disabled(!isValidURL || isImporting)
            .opacity(isImporting ? 0.7 : 1)
        }
        .padding(.horizontal)
        .padding(.bottom, 12)
        .background(
            Color(UIColor.systemGroupedBackground)
                .ignoresSafeArea(edges: .bottom)
        )
    }

    // MARK: - Validation

    private var isValidURL: Bool {
        guard !recipeURL.isEmpty else { return false }
        if let url = URL(string: recipeURL),
           let scheme = url.scheme,
           (scheme == "http" || scheme == "https"),
           url.host != nil {
            return true
        }
        // Also accept URLs without scheme (we'll add https)
        if !recipeURL.contains("://") {
            let urlWithScheme = "https://" + recipeURL
            if let url = URL(string: urlWithScheme),
               url.host != nil {
                return true
            }
        }
        return false
    }

    // MARK: - Actions

    private func importRecipe() {
        guard isValidURL else { return }

        var finalURL = recipeURL
        // Add https if no scheme provided
        if !recipeURL.contains("://") {
            finalURL = "https://" + recipeURL
        }

        isImporting = true
        errorMessage = nil

        foodManager.importRecipe(url: finalURL) { result in
            DispatchQueue.main.async {
                isImporting = false
                switch result {
                case .success(let recipe):
                    // Recipe imported successfully
                    importedRecipe = recipe
                    // Refresh the recipes list
                    Task {
                        await RecipesRepository.shared.refresh(force: true)
                    }
                    // Post notification to navigate or show success
                    NotificationCenter.default.post(name: NSNotification.Name("RecipeImported"), object: recipe)
                    dismiss()
                case .failure(let error):
                    errorMessage = "Failed to import recipe. Please check the URL and try again."
                    print("Import error: \(error)")
                }
            }
        }
    }
}

#Preview {
    ImportRecipeSheet()
        .environmentObject(FoodManager())
}
