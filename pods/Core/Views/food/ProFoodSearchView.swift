import SwiftUI

struct ProFoodSearchView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var proFeatureGate: ProFeatureGate
    @State private var query: String = ""
    @State private var result: ProFoodSearchResult?
    @State private var isLoading = false
    @State private var errorMessage: String?
    let userEmail: String
    private let networkManager = NetworkManager()
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Ask Humuli Intelligence")
                        .font(.title2.weight(.bold))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("Describe any meal to get nutrition with sources.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top)
                
                TextField("Chipotle chicken bowl", text: $query)
                    .textFieldStyle(.roundedBorder)
                    .submitLabel(.search)
                    .onSubmit { runSearch() }
                
                if isLoading {
                    ProgressView("Searching…")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                if let errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                if let result {
                    ResultCard(result: result)
                } else {
                    Spacer()
                }
            }
            .padding()
            .navigationTitle("Pro Food Search")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
    
    private func runSearch() {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        isLoading = true
        errorMessage = nil
        networkManager.searchFoodPro(query: trimmed, userEmail: userEmail) { result in
            DispatchQueue.main.async {
                self.isLoading = false
                switch result {
                case .success(let response):
                    self.result = response
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    private struct ResultCard: View {
        let result: ProFoodSearchResult
        
        var body: some View {
            VStack(alignment: .leading, spacing: 12) {
                Text(result.name ?? "Result")
                    .font(.title3.weight(.semibold))
                if let serving = result.serving {
                    Text(serving)
                        .foregroundColor(.secondary)
                }
                if let calories = result.calories {
                    Text("Calories: \(Int(calories))")
                }
                if let macros = result.macros {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Protein: \(format(macros.proteinG)) g")
                        Text("Carbs: \(format(macros.carbsG)) g")
                        Text("Fat: \(format(macros.fatG)) g")
                    }
                }
                if let micros = result.micros, !micros.isEmpty {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Micronutrients")
                            .font(.subheadline.weight(.medium))
                        ForEach(Array(micros.enumerated()), id: \.offset) { _, item in
                            Text("• \(item.name): \(item.amount)")
                                .font(.footnote)
                        }
                    }
                }
                if let sources = result.sources, !sources.isEmpty {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Sources")
                            .font(.subheadline.weight(.medium))
                        ForEach(sources, id: \.self) { source in
                            if let url = URL(string: source) {
                                Link(source, destination: url)
                                    .font(.footnote)
                            } else {
                                Text(source)
                                    .font(.footnote)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
            .padding()
            .background(RoundedRectangle(cornerRadius: 16).fill(Color(.systemGray6)))
        }
        
        private func format(_ value: Double?) -> String {
            guard let value else { return "--" }
            return String(format: "%.1f", value)
        }
    }
}
