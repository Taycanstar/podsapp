import SwiftUI

// MARK: - UserDefaults Keys for Onboarding Flows
extension UserDefaults {
    private enum OnboardingKeys {
        static let hasSeenLogFlow = "hasSeenLogFlow"
        static let hasSeenAllFlow = "hasSeenAllFlow"
        static let hasSeenMealFlow = "hasSeenMealFlow"
        static let hasSeenFoodFlow = "hasSeenFoodFlow"
        static let hasSeenScanFlow = "hasSeenScanFlow"
    }
    
    // Helper methods for checking onboarding flow status
    var hasSeenLogFlow: Bool {
        get { bool(forKey: OnboardingKeys.hasSeenLogFlow) }
        set { set(newValue, forKey: OnboardingKeys.hasSeenLogFlow) }
    }
    
    var hasSeenAllFlow: Bool {
        get { bool(forKey: OnboardingKeys.hasSeenAllFlow) }
        set { set(newValue, forKey: OnboardingKeys.hasSeenAllFlow) }
    }
    
    var hasSeenMealFlow: Bool {
        get { bool(forKey: OnboardingKeys.hasSeenMealFlow) }
        set { set(newValue, forKey: OnboardingKeys.hasSeenMealFlow) }
    }
    
    var hasSeenFoodFlow: Bool {
        get { bool(forKey: OnboardingKeys.hasSeenFoodFlow) }
        set { set(newValue, forKey: OnboardingKeys.hasSeenFoodFlow) }
    }
    
    var hasSeenScanFlow: Bool {
        get { bool(forKey: OnboardingKeys.hasSeenScanFlow) }
        set { set(newValue, forKey: OnboardingKeys.hasSeenScanFlow) }
    }
    
    // Method to reset all onboarding flows (useful for testing)
    func resetAllOnboardingFlows() {
        hasSeenLogFlow = false
        hasSeenAllFlow = false
        hasSeenMealFlow = false
        hasSeenFoodFlow = false
        hasSeenScanFlow = false
        
        // Force synchronize to ensure changes are saved immediately
        UserDefaults.standard.synchronize()
        print("🔄 All onboarding flows reset to false")
    }
}

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

enum NavigationDirection { // Added enum for navigation direction
    case forward, backward
}

class LogFlow: ObservableObject {
    @Published var currentStep: LogStep = .tapPlus
    @Published var progress: Double = 0.0
    @Published var navigationDirection: NavigationDirection = .forward // Added property
    
    // Completion callback to notify when flow is finished
    var onFlowCompleted: (() -> Void)?

    init() {
        updateProgress()
    }

    func navigate(to step: LogStep) {
        if step.rawValue > currentStep.rawValue {
            navigationDirection = .forward
        } else if step.rawValue < currentStep.rawValue {
            navigationDirection = .backward
        }
        // If step.rawValue == currentStep.rawValue, direction doesn't change or matter as much

        withAnimation {
            currentStep = step
        }
        updateProgress()
    }

    func next() {
        if let nextStep = LogStep(rawValue: currentStep.rawValue + 1) {
            navigationDirection = .forward // Set direction
            withAnimation {
                currentStep = nextStep
            }
        }
        updateProgress()
    }

    func previous() {
        if let prevStep = LogStep(rawValue: currentStep.rawValue - 1) {
            navigationDirection = .backward // Set direction
            withAnimation {
                currentStep = prevStep
            }
        }
        updateProgress()
    }
    
    func completeFlow() {
        print("🔍 LogFlow - completeFlow() called")
        UserDefaults.standard.hasSeenLogFlow = true
        onFlowCompleted?()
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
    @Published var navigationDirection: NavigationDirection = .forward // Added property

    init() {
        updateProgress()
    }

    func navigate(to step: AllStep) {
        if step.rawValue > currentStep.rawValue {
            navigationDirection = .forward
        } else if step.rawValue < currentStep.rawValue {
            navigationDirection = .backward
        }
        withAnimation {
            currentStep = step
        }
        updateProgress()
    }
    
    func next() {
        if let nextStep = AllStep(rawValue: currentStep.rawValue + 1) {
            navigationDirection = .forward // Set direction
            withAnimation {
                currentStep = nextStep
            }
        }
        updateProgress()
    }

    func previous() {
        if let prevStep = AllStep(rawValue: currentStep.rawValue - 1) {
            navigationDirection = .backward // Set direction
            withAnimation {
                currentStep = prevStep
            }
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
    @Published var navigationDirection: NavigationDirection = .forward // Added property

    init() {
        updateProgress()
    }
    
    func navigate(to step: MealStep) {
        if step.rawValue > currentStep.rawValue {
            navigationDirection = .forward
        } else if step.rawValue < currentStep.rawValue {
            navigationDirection = .backward
        }
        withAnimation {
            currentStep = step
        }
        updateProgress()
    }

    func next() {
        if let nextStep = MealStep(rawValue: currentStep.rawValue + 1) {
            navigationDirection = .forward // Set direction
            withAnimation {
                currentStep = nextStep
            }
        }
        updateProgress()
    }

    func previous() {
        if let prevStep = MealStep(rawValue: currentStep.rawValue - 1) {
            navigationDirection = .backward // Set direction
            withAnimation {
                currentStep = prevStep
            }
        }
        updateProgress()
    }

    private func updateProgress() {
        progress = (Double(currentStep.rawValue) + 1.0) / Double(MealStep.allCases.count)
    }
}

// MARK: - Foods Flow

enum FoodStep: Int, CaseIterable {
    case describeFood, generateFood, tapCreateFood, nameFood

    @ViewBuilder
    var view: some View {
        switch self {
        case .describeFood:
            DescribeFoodView() // Uses food0
        case .generateFood:
            GenerateFoodView() // Uses food1
        case .tapCreateFood:
            TapCreateFoodView() // Uses food2
        case .nameFood:
            NameFoodView() // Uses food3
        }
    }
}

class FoodFlow: ObservableObject {
    @Published var currentStep: FoodStep = .describeFood
    @Published var progress: Double = 0.0
    @Published var navigationDirection: NavigationDirection = .forward

    init() {
        updateProgress()
    }

    func navigate(to step: FoodStep) {
        if step.rawValue > currentStep.rawValue {
            navigationDirection = .forward
        } else if step.rawValue < currentStep.rawValue {
            navigationDirection = .backward
        }
        withAnimation {
            currentStep = step
        }
        updateProgress()
    }

    func next() {
        if let nextStep = FoodStep(rawValue: currentStep.rawValue + 1) {
            navigationDirection = .forward
            withAnimation {
                currentStep = nextStep
            }
        }
        updateProgress()
    }

    func previous() {
        if let prevStep = FoodStep(rawValue: currentStep.rawValue - 1) {
            navigationDirection = .backward
            withAnimation {
                currentStep = prevStep
            }
        }
        updateProgress()
    }

    private func updateProgress() {
        progress = (Double(currentStep.rawValue) + 1.0) / Double(FoodStep.allCases.count)
    }
}

// MARK: - Food Flow Container

struct FoodFlowContainerView: View {
    @StateObject var foodFlow = FoodFlow()
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Custom Navigation Bar Area
                HStack(spacing: 16) {
                    if foodFlow.currentStep != FoodStep.allCases.first {
                        Button(action: {
                            foodFlow.previous()
                        }) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(Color.primary)
                        }
                    } else {
                        Button(action: {
                            dismiss()
                        }) {
                            Image(systemName: "chevron.left") 
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(Color.primary)
                        }
                    }

                    ProgressView(value: foodFlow.progress)
                        .progressViewStyle(LinearProgressViewStyle(tint: Color.primary))
                }
                .padding(.horizontal)
                .frame(height: 44) 
                .padding(.top, (UIApplication.shared.windows.first?.safeAreaInsets.top ?? 0) > 20 ? 10 : 20)
                .background(Color("bg").edgesIgnoringSafeArea(.top))
                
                foodFlow.currentStep.view
                    .environmentObject(foodFlow) 
                    .frame(maxWidth: .infinity, maxHeight: .infinity) 
                    .id(foodFlow.currentStep) 
                    .transition(.asymmetric( 
                        insertion: foodFlow.navigationDirection == .forward ? .move(edge: .trailing) : .move(edge: .leading),
                        removal: foodFlow.navigationDirection == .forward ? .move(edge: .leading) : .move(edge: .trailing)
                    ))
                    .animation(.default, value: foodFlow.currentStep) 
            }
            .navigationBarHidden(true) 
            .background(Color("bg").edgesIgnoringSafeArea(.all))
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .onDisappear {
            // Mark food flow as seen
            print("🔍 FoodFlowContainerView onDisappear - marking hasSeenFoodFlow = true")
            UserDefaults.standard.hasSeenFoodFlow = true
        }
    }
}

#if DEBUG
struct FoodFlowContainerView_Previews: PreviewProvider {
    static var previews: some View {
        FoodFlowContainerView()
    }
}
#endif 

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
                .background(Color("bg").edgesIgnoringSafeArea(.top)) // Match view background
                
                // Content View from the current step of the LogFlow
                logFlow.currentStep.view
                    .environmentObject(logFlow) // Pass the LogFlow to the child view
                    .frame(maxWidth: .infinity, maxHeight: .infinity) // Ensure it fills the space
                    .id(logFlow.currentStep) // Add ID for better transition handling
                    .transition(.asymmetric( // Use dynamic transition
                        insertion: logFlow.navigationDirection == .forward ? .move(edge: .trailing) : .move(edge: .leading),
                        removal: logFlow.navigationDirection == .forward ? .move(edge: .leading) : .move(edge: .trailing)
                    ))
                    .animation(.default, value: logFlow.currentStep) // Animate based on currentStep
            }
            .navigationBarHidden(true) // Hide the default navigation bar, we're using a custom one
            .background(Color("bg").edgesIgnoringSafeArea(.all))
        }
        .navigationViewStyle(StackNavigationViewStyle()) // Recommended for flows like this
        .onAppear {
            // Set up the completion callback
            logFlow.onFlowCompleted = {
                print("🔍 LogFlowContainerView - Flow completed, dismissing sheet")
                dismiss()
            }
        }
        .onDisappear {
            // Mark log flow as seen (backup in case completeFlow() wasn't called)
            print("🔍 LogFlowContainerView onDisappear - marking hasSeenLogFlow = true")
            UserDefaults.standard.hasSeenLogFlow = true
        }
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

// MARK: - All Flow Container

struct AllFlowContainerView: View {
    @StateObject var allFlow = AllFlow()
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Custom Navigation Bar Area
                HStack(spacing: 16) {
                    if allFlow.currentStep != AllStep.allCases.first {
                        Button(action: {
                            allFlow.previous()
                        }) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(Color.primary)
                        }
                    } else {
                        Button(action: {
                            dismiss()
                        }) {
                            Image(systemName: "chevron.left") 
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(Color.primary)
                        }
                    }

                    ProgressView(value: allFlow.progress)
                        .progressViewStyle(LinearProgressViewStyle(tint: Color.primary))
                }
                .padding(.horizontal)
                .frame(height: 44) 
                .padding(.top, (UIApplication.shared.windows.first?.safeAreaInsets.top ?? 0) > 20 ? 10 : 20)
                .background(Color("bg").edgesIgnoringSafeArea(.top))
                
                allFlow.currentStep.view
                    .environmentObject(allFlow) 
                    .frame(maxWidth: .infinity, maxHeight: .infinity) 
                    .id(allFlow.currentStep) 
                    .transition(.asymmetric( 
                        insertion: allFlow.navigationDirection == .forward ? .move(edge: .trailing) : .move(edge: .leading),
                        removal: allFlow.navigationDirection == .forward ? .move(edge: .leading) : .move(edge: .trailing)
                    ))
                    .animation(.default, value: allFlow.currentStep) 
            }
            .navigationBarHidden(true) 
            .background(Color("bg").edgesIgnoringSafeArea(.all))
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .onDisappear {
            // Mark all flow as seen
            print("🔍 AllFlowContainerView onDisappear - marking hasSeenAllFlow = true")
            UserDefaults.standard.hasSeenAllFlow = true
        }
    }
}

#if DEBUG
struct AllFlowContainerView_Previews: PreviewProvider {
    static var previews: some View {
        AllFlowContainerView()
    }
}
#endif 

// MARK: - Meal Flow Container

struct MealFlowContainerView: View {
    @StateObject var mealFlow = MealFlow()
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Custom Navigation Bar Area
                HStack(spacing: 16) {
                    if mealFlow.currentStep != MealStep.allCases.first {
                        Button(action: {
                            mealFlow.previous()
                        }) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(Color.primary)
                        }
                    } else {
                        Button(action: {
                            dismiss()
                        }) {
                            Image(systemName: "chevron.left") 
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(Color.primary)
                        }
                    }

                    ProgressView(value: mealFlow.progress)
                        .progressViewStyle(LinearProgressViewStyle(tint: Color.primary))
                }
                .padding(.horizontal)
                .frame(height: 44) 
                .padding(.top, (UIApplication.shared.windows.first?.safeAreaInsets.top ?? 0) > 20 ? 10 : 20)
                .background(Color("bg").edgesIgnoringSafeArea(.top))
                
                mealFlow.currentStep.view
                    .environmentObject(mealFlow) 
                    .frame(maxWidth: .infinity, maxHeight: .infinity) 
                    .id(mealFlow.currentStep) 
                    .transition(.asymmetric( 
                        insertion: mealFlow.navigationDirection == .forward ? .move(edge: .trailing) : .move(edge: .leading),
                        removal: mealFlow.navigationDirection == .forward ? .move(edge: .leading) : .move(edge: .trailing)
                    ))
                    .animation(.default, value: mealFlow.currentStep) 
            }
            .navigationBarHidden(true) 
            .background(Color("bg").edgesIgnoringSafeArea(.all))
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .onDisappear {
            // Mark meal flow as seen
            print("🔍 MealFlowContainerView onDisappear - marking hasSeenMealFlow = true")
            UserDefaults.standard.hasSeenMealFlow = true
        }
    }
}

#if DEBUG
struct MealFlowContainerView_Previews: PreviewProvider {
    static var previews: some View {
        MealFlowContainerView()
    }
}
#endif 

// MARK: - Scan Flow

enum ScanStep: Int, CaseIterable {
    case scanFood, barcode, gallery

    @ViewBuilder
    var view: some View {
        switch self {
        case .scanFood:
            ScanFoodHelper() // Uses scan3
        case .barcode:
            BarcodeHelper() // Uses scan2
        case .gallery:
            GalleryHelper() // Uses scan1
        }
    }
}

class ScanFlow: ObservableObject {
    @Published var currentStep: ScanStep = .scanFood
    @Published var progress: Double = 0.0
    @Published var navigationDirection: NavigationDirection = .forward

    init() {
        updateProgress()
    }

    func navigate(to step: ScanStep) {
        if step.rawValue > currentStep.rawValue {
            navigationDirection = .forward
        } else if step.rawValue < currentStep.rawValue {
            navigationDirection = .backward
        }
        withAnimation {
            currentStep = step
        }
        updateProgress()
    }

    func next() {
        if let nextStep = ScanStep(rawValue: currentStep.rawValue + 1) {
            navigationDirection = .forward
            withAnimation {
                currentStep = nextStep
            }
        }
        updateProgress()
    }

    func previous() {
        if let prevStep = ScanStep(rawValue: currentStep.rawValue - 1) {
            navigationDirection = .backward
            withAnimation {
                currentStep = prevStep
            }
        }
        updateProgress()
    }

    private func updateProgress() {
        progress = (Double(currentStep.rawValue) + 1.0) / Double(ScanStep.allCases.count)
    }
}

// MARK: - Scan Flow Container

struct ScanFlowContainerView: View {
    @StateObject var scanFlow = ScanFlow()
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Custom Navigation Bar Area
                HStack(spacing: 16) {
                    if scanFlow.currentStep != ScanStep.allCases.first {
                        Button(action: {
                            scanFlow.previous()
                        }) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(Color.primary)
                        }
                    } else {
                        Button(action: {
                            dismiss()
                        }) {
                            Image(systemName: "chevron.left") 
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(Color.primary)
                        }
                    }

                    ProgressView(value: scanFlow.progress)
                        .progressViewStyle(LinearProgressViewStyle(tint: Color.primary))
                }
                .padding(.horizontal)
                .frame(height: 44) 
                .padding(.top, (UIApplication.shared.windows.first?.safeAreaInsets.top ?? 0) > 20 ? 10 : 20)
                .background(Color("bg").edgesIgnoringSafeArea(.top))
                
                scanFlow.currentStep.view
                    .environmentObject(scanFlow) 
                    .frame(maxWidth: .infinity, maxHeight: .infinity) 
                    .id(scanFlow.currentStep) 
                    .transition(.asymmetric( 
                        insertion: scanFlow.navigationDirection == .forward ? .move(edge: .trailing) : .move(edge: .leading),
                        removal: scanFlow.navigationDirection == .forward ? .move(edge: .leading) : .move(edge: .trailing)
                    ))
                    .animation(.default, value: scanFlow.currentStep) 
            }
            .navigationBarHidden(true) 
            .background(Color("bg").edgesIgnoringSafeArea(.all))
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .onDisappear {
            // Mark scan flow as seen
            print("🔍 ScanFlowContainerView onDisappear - marking hasSeenScanFlow = true")
            UserDefaults.standard.hasSeenScanFlow = true
        }
    }
}

#if DEBUG
struct ScanFlowContainerView_Previews: PreviewProvider {
    static var previews: some View {
        ScanFlowContainerView()
    }
}
#endif 