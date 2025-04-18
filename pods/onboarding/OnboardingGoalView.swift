// Continue button
VStack {
    NavigationLink(destination: DesiredWeightView(), isActive: $navigateToNextStep) {
        Button(action: {
            HapticFeedback.generate()
            saveGoal()
            navigateToNextStep = true
        }) {
            Text("Continue")
                .font(.system(size: 18, weight: .semibold))
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(Color.accentColor)
                .foregroundColor(.white)
                .cornerRadius(12)
        }
    }
    .padding(.horizontal)
    .padding(.vertical, 16)
} 