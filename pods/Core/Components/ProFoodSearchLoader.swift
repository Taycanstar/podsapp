import SwiftUI

struct ProFoodSearchLoader: View {
    @State private var shimmerOffset: CGFloat = -200
    
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject private var foodManager: FoodManager
    
    var body: some View {
        let shimmerColor = colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.05)
        
        VStack(spacing: 16) {
            header
            progressBar(shimmerColor: shimmerColor)
            footerStatus(shimmerColor: shimmerColor)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color("containerbg"))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(shimmerGradient(shimmerColor))
                        .opacity(0.8)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(colorScheme == .dark ? Color(.systemGray5) : Color(.systemGray4), lineWidth: 0.5)
                )
        )
        .accessibilityLabel("Metryc Pro Search is finishing up.")
    }
    
    private var header: some View {
        HStack(spacing: 12) {
            Image("logx")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 24, height: 24)
            
            Text("Metryc Pro Search")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.primary)
            
            Spacer()
        }
    }
    
    private func progressBar(shimmerColor: Color) -> some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 4)
                
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.accentColor)
                    .frame(width: geometry.size.width * foodManager.animatedProgress, height: 4)
                    .animation(.easeInOut(duration: 0.45), value: foodManager.animatedProgress)
            }
        }
        .frame(height: 4)
        .onAppear {
            if reduceMotion {
                // No animation; rely on static progress updates
            } else {
                startShimmerAnimation()
            }
        }
        .onDisappear {
            shimmerOffset = -200
        }
    }
    
    private func footerStatus(shimmerColor: Color) -> some View {
        HStack {
            Text("Sourcing verified nutrition data…")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)
            
            Spacer()
        }
    }
    
    private func shimmerGradient(_ shimmerColor: Color) -> LinearGradient {
        LinearGradient(
            gradient: Gradient(stops: [
                .init(color: .clear, location: 0),
                .init(color: shimmerColor, location: 0.5),
                .init(color: .clear, location: 1)
            ]),
            startPoint: .init(x: -0.3 + shimmerOffset/200, y: 0),
            endPoint: .init(x: 0.3 + shimmerOffset/200, y: 0)
        )
    }
    
    private func startShimmerAnimation() {
        guard !reduceMotion else { return }
        shimmerOffset = -200
        withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
            shimmerOffset = 200
        }
    }
}
