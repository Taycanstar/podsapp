import SwiftUI

// MARK: - Log Flow

enum LogStep: Int, CaseIterable {
    case tapPlus, newMenu

    @ViewBuilder
    var view: some View {
        switch self {
        case .tapPlus:
            TapPlusView()
        case .newMenu:
            NewMenuView()
        }
    }
}

class LogFlow: ObservableObject {
    @Published var currentStep: LogStep = .tapPlus
    @Published var progress: Double = 0.0

    init() {
        updateProgress()
    }

    func navigate(to step: LogStep) {
        currentStep = step
        updateProgress()
    }

    func next() {
        if let nextStep = LogStep(rawValue: currentStep.rawValue + 1) {
            currentStep = nextStep
        }
        updateProgress()
    }

    func previous() {
        if let prevStep = LogStep(rawValue: currentStep.rawValue - 1) {
            currentStep = prevStep
        }
        updateProgress()
    }

    private func updateProgress() {
        progress = (Double(currentStep.rawValue) + 1.0) / Double(LogStep.allCases.count)
    }
}

// MARK: - All Flow

enum AllStep: Int, CaseIterable {
    case describeLog, generateLog, tapQuickLog, addQuickLog, logExisting

    @ViewBuilder
    var view: some View {
        switch self {
        case .describeLog:
            DescribeLogView()
        case .generateLog:
            GenerateLogView()
        case .tapQuickLog:
            TapQuickLogView()
        case .addQuickLog:
            AddQuickLogDetailsView()
        case .logExisting:
            LogExistingView()
        }
    }
}

class AllFlow: ObservableObject {
    @Published var currentStep: AllStep = .describeLog
    @Published var progress: Double = 0.0

    init() {
        updateProgress()
    }

    func navigate(to step: AllStep) {
        currentStep = step
        updateProgress()
    }
    
    func next() {
        if let nextStep = AllStep(rawValue: currentStep.rawValue + 1) {
            currentStep = nextStep
        }
        updateProgress()
    }

    func previous() {
        if let prevStep = AllStep(rawValue: currentStep.rawValue - 1) {
            currentStep = prevStep
        }
        updateProgress()
    }

    private func updateProgress() {
        progress = (Double(currentStep.rawValue) + 1.0) / Double(AllStep.allCases.count)
    }
}

// MARK: - Meals Flow

enum MealStep: Int, CaseIterable {
    case describeMeal, generateMeal, tapCreateMeal, nameMeal, findFoods

    @ViewBuilder
    var view: some View {
        switch self {
        case .describeMeal:
            DescribeMealView()
        case .generateMeal:
            GenerateMealView()
        case .tapCreateMeal:
            TapCreateMealView()
        case .nameMeal:
            NameMealView()
        case .findFoods:
            FindFoodsView()
        }
    }
}

class MealFlow: ObservableObject {
    @Published var currentStep: MealStep = .describeMeal
    @Published var progress: Double = 0.0

    init() {
        updateProgress()
    }
    
    func navigate(to step: MealStep) {
        currentStep = step
        updateProgress()
    }

    func next() {
        if let nextStep = MealStep(rawValue: currentStep.rawValue + 1) {
            currentStep = nextStep
        }
        updateProgress()
    }

    func previous() {
        if let prevStep = MealStep(rawValue: currentStep.rawValue - 1) {
            currentStep = prevStep
        }
        updateProgress()
    }

    private func updateProgress() {
        progress = (Double(currentStep.rawValue) + 1.0) / Double(MealStep.allCases.count)
    }
}

// MARK: - Foods Flow

enum FoodStep: Int, CaseIterable {
    case describeFood, tapCreateFood, nameFood

    @ViewBuilder
    var view: some View {
        switch self {
        case .describeFood:
            DescribeFoodView()
        case .tapCreateFood:
            TapCreateFoodView()
        case .nameFood:
            NameFoodView()
        }
    }
}

class FoodFlow: ObservableObject {
    @Published var currentStep: FoodStep = .describeFood
    @Published var progress: Double = 0.0

    init() {
        updateProgress()
    }
    
    func navigate(to step: FoodStep) {
        currentStep = step
        updateProgress()
    }

    func next() {
        if let nextStep = FoodStep(rawValue: currentStep.rawValue + 1) {
            currentStep = nextStep
        }
        updateProgress()
    }

    func previous() {
        if let prevStep = FoodStep(rawValue: currentStep.rawValue - 1) {
            currentStep = prevStep
        }
        updateProgress()
    }

    private func updateProgress() {
        progress = (Double(currentStep.rawValue) + 1.0) / Double(FoodStep.allCases.count)
    }
}

// MARK: - Log Flow Container

struct LogFlowContainerView: View {
    @StateObject var logFlow = LogFlow()
    @Environment(\.dismiss) var dismiss // For dismissing the entire flow if presented modally

    var body: some View {
        // Using a NavigationView here to provide the navigation bar context for its children.
        // If this LogFlowContainerView is itself pushed onto a NavigationView stack, 
        // you might not need this NavigationView, or might need to use .navigationBarHidden(true)
        // on the parent to avoid double navigation bars.
        NavigationView {
            VStack(spacing: 0) {
                // Custom Navigation Bar Area
                HStack(spacing: 16) { // Changed from VStack to HStack, added spacing
                    if logFlow.currentStep != LogStep.allCases.first {
                        Button(action: {
                            // HapticFeedback.generate() // Uncomment if you have HapticFeedback
                            logFlow.previous()
                        }) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(Color.primary)
                        }
                    } else {
                        // Option to dismiss the entire flow if it's modal and on the first step
                        Button(action: {
                            // HapticFeedback.generate()
                            dismiss()
                        }) {
                            Image(systemName: "chevron.left") // Or use "xmark" for modal close
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(Color.primary)
                        }
                    }
                    // Spacer() // Removed spacer that was here before, to put progress bar next to button

                    ProgressView(value: logFlow.progress)
                        .progressViewStyle(LinearProgressViewStyle(tint: Color.primary)) // Tint for progress bar
                        // .padding(.horizontal) // Removed horizontal padding, parent HStack handles it
                    
                    // If you want a title or other items on the trailing side, add them here with a Spacer before the ProgressView
                    // For now, the ProgressView will expand.
                }
                .padding(.horizontal) // Apply horizontal padding to the HStack itself
                .frame(height: 44) // Standard iOS navigation bar height
                .padding(.top, (UIApplication.shared.windows.first?.safeAreaInsets.top ?? 0) > 20 ? 10 : 20) // Adjust top padding based on safe area
                .background(Color("iosbg").edgesIgnoringSafeArea(.top)) // Match view background
                
                // Content View from the current step of the LogFlow
                logFlow.currentStep.view
                    .environmentObject(logFlow) // Pass the LogFlow to the child view
                    .frame(maxWidth: .infinity, maxHeight: .infinity) // Ensure it fills the space
            }
            .navigationBarHidden(true) // Hide the default navigation bar, we're using a custom one
            .background(Color("iosbg").edgesIgnoringSafeArea(.all))
        }
        .navigationViewStyle(StackNavigationViewStyle()) // Recommended for flows like this
    }
}

#if DEBUG
struct LogFlowContainerView_Previews: PreviewProvider {
    static var previews: some View {
        LogFlowContainerView()
    }
}
#endif

/*
// Example Usage:
struct LogFlowContainerView: View {
    @StateObject var logFlow = LogFlow()

    var body: some View {
        NavigationView {
            VStack {
                ProgressView(value: logFlow.progress)
                    .padding(.horizontal)
                    .padding(.top)
                
                // The view from the current step
                logFlow.currentStep.view
                    .environmentObject(logFlow) // If views need access to the flow

                Spacer()
                
                HStack {
                    if logFlow.currentStep.rawValue > 0 {
                        Button("Back") { logFlow.previous() }
                    }
                    Spacer()
                    if logFlow.currentStep.rawValue < LogStep.allCases.count - 1 {
                        Button("Next") { logFlow.next() }
                    } else {
                        Button("Finish") {
                            // Handle flow completion
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Log Flow Step \\(logFlow.currentStep.rawValue + 1)")
        }
    }
}
*/ 