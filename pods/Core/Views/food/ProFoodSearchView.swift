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
                    Text("Ask Metryc Intelligence")
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
                
                Group {
                    if let result {
                        ResultCard(result: result)
                    } else {
                        Spacer()
                    }
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
            VStack(alignment: .leading, spacing: 20) {
                headerSection
                
                if let macros = result.macros {
                    macroSection(macros: macros)
                }
                
                if let micros = result.micros, !micros.isEmpty {
                    microSection(micros: micros)
                }
                
                if let sources = result.sources, !sources.isEmpty {
                    sourceSection(sources: sources)
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color("iosfit"))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.primary.opacity(0.05), lineWidth: 1)
            )
        }
        
        @ViewBuilder
        private var headerSection: some View {
            VStack(alignment: .leading, spacing: 8) {
                Text(result.name ?? "Result")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.primary)
                
                if let brand = result.brand, !brand.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(brand)
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.secondary)
                }
                
                if let serving = result.serving, !serving.isEmpty {
                    Text(serving)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                if let calories = result.calories {
                    Text("\(Int(calories.rounded())) kcal")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundColor(.primary)
                        .padding(.top, 4)
                }
            }
        }
        
        @ViewBuilder
        private func macroSection(macros: ProFoodSearchResult.Macros) -> some View {
            VStack(alignment: .leading, spacing: 10) {
                Text("Macronutrients")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.secondary)
                
                HStack(spacing: 12) {
                    MacroTile(label: "Protein", value: macros.proteinG, tint: .pink)
                    MacroTile(label: "Carbs", value: macros.carbsG, tint: .orange)
                    MacroTile(label: "Fat", value: macros.fatG, tint: .purple)
                }
            }
        }
        
        @ViewBuilder
        private func microSection(micros: [ProFoodSearchResult.Micro]) -> some View {
            VStack(alignment: .leading, spacing: 8) {
                Text("Micronutrients")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.secondary)
                
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(micros.enumerated()), id: \.offset) { _, item in
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Circle()
                                .fill(Color.accentColor.opacity(0.2))
                                .frame(width: 6, height: 6)
                            Text("\(item.name): \(item.amount)")
                                .font(.footnote)
                                .foregroundColor(.primary)
                        }
                    }
                }
            }
        }
        
        @ViewBuilder
        private func sourceSection(sources: [String]) -> some View {
            VStack(alignment: .leading, spacing: 8) {
                Text("Sources")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.secondary)
                
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(sources, id: \.self) { source in
                        if let url = URL(string: source) {
                            Link(destination: url) {
                                Text(source)
                                    .font(.footnote)
                                    .foregroundColor(.accentColor)
                                    .multilineTextAlignment(.leading)
                            }
                        } else {
                            Text(source)
                                .font(.footnote)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        
        private struct MacroTile: View {
            let label: String
            let value: Double?
            let tint: Color
            
            var body: some View {
                VStack(alignment: .leading, spacing: 6) {
                    Text(label.uppercased())
                        .font(.caption2.weight(.heavy))
                        .foregroundColor(tint.opacity(0.9))
                    Text("\(format(value)) g")
                        .font(.title3.weight(.semibold))
                        .foregroundColor(.primary)
                    Text("per serving")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 14)
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(tint.opacity(0.12))
                )
            }
            
            private func format(_ value: Double?) -> String {
                guard let value else { return "--" }
                return String(format: "%.1f", value)
            }
        }
    }
}
