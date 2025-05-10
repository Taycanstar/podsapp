//
//  DashboardView.swift
//  Pods
//
//  Created by Dimi Nunez on 1/26/25.
//

import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var podsViewModel: PodsViewModel
    @EnvironmentObject var viewModel: OnboardingViewModel
    @EnvironmentObject var foodManager: FoodManager
    @Environment(\.isTabBarVisible) var isTabBarVisible
    
    @State private var showScanningErrorAlert = false
    @State private var selectedDate = Date()
    @State private var showDatePickerSheet = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Color("iosbg2")
                    .edgesIgnoringSafeArea(.all)
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
           
                        
                        // Nutrition Summary Cards
                        VStack(spacing: 10) {
                            // Remaining Calories Card
                            HStack(spacing: 16) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Remaining")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.secondary)
                                    
                                    Text("\(Int(foodManager.remainingCalories))cal")
                                        .font(.system(size: 32, weight: .bold))
                                }
                                
                                Spacer()
                                
                                // Circular Progress Indicator
                                ZStack {
                                    Circle()
                                        .stroke(lineWidth: 10)
                                        .opacity(0.2)
                                        .foregroundColor(Color.green)
                                    
                                    Circle()
                                        .trim(from: 0.0, to: min(1.0, CGFloat(1 - (foodManager.remainingCalories / foodManager.calorieGoal))))
                                        .stroke(style: StrokeStyle(lineWidth: 10, lineCap: .round, lineJoin: .round))
                                        .foregroundColor(Color.green)
                                        .rotationEffect(Angle(degrees: 270.0))
                                        .animation(.linear, value: foodManager.remainingCalories)
                                }
                                .frame(width: 60, height: 60)
                            }
                            .padding()
                            .background(Color("iosnp"))
                            .cornerRadius(12)
                            
                            // Macronutrients Card
                            VStack(spacing: 16) {
                                // First row: Calories and Protein
                                HStack(spacing: 0) {
                                    // Calories
                                    HStack(alignment: .top, spacing: 12) {
                                        ZStack {
                                            Circle()
                                                .fill(Color.orange.opacity(0.2))
                                                .frame(width: 40, height: 40)
                                            
                                            Image(systemName: "flame.fill")
                                                .foregroundColor(.orange)
                                        }
                                        
                                        VStack(alignment: .leading, spacing: 0) {
                                            Text("Calories")
                                                .font(.system(size: 16, weight: .regular))
                                            
                                            Text("\(Int(foodManager.caloriesConsumed))")
                                                .font(.system(size: 18, weight: .semibold, design: .rounded))
                                                .foregroundColor(.orange)
                                        }
                                        
                                        Spacer(minLength: 0)
                                    }
                                    .frame(maxWidth: .infinity)
                                    
                                    // Protein
                                    HStack(alignment: .top, spacing: 12) {
                                        ZStack {
                                            Circle()
                                                .fill(Color.blue.opacity(0.2))
                                                .frame(width: 40, height: 40)
                                            
                                            Image(systemName: "fish")
                                                .foregroundColor(.blue)
                                        }
                                        
                                        VStack(alignment: .leading, spacing: 0) {
                                            Text("Protein")
                                                 .font(.system(size: 16, weight: .regular))
                                            
                                            Text("\(Int(foodManager.proteinConsumed))g")
                                                .font(.system(size: 18, weight: .semibold, design: .rounded))
                                                .foregroundColor(.blue)
                                        }
                                        
                                        Spacer(minLength: 0)
                                    }
                                    .frame(maxWidth: .infinity)
                                }
                                
                                // Second row: Carbs and Fat
                                HStack(spacing: 0) {
                                    // Carbs
                                    HStack(alignment: .top, spacing: 12) {
                                        ZStack {
                                            Circle()
                                                .fill(Color.purple.opacity(0.2))
                                                .frame(width: 40, height: 40)
                                            
                                            Image(systemName: "laurel.leading")
                                                .foregroundColor(.purple)
                                                .font(.system(size: 20))
                                        }
                                        
                                        VStack(alignment: .leading, spacing: 0) {
                                            Text("Carbs")
                                                .font(.system(size: 16, weight: .regular))
                                            
                                            Text("\(Int(foodManager.carbsConsumed))g")
                                                .font(.system(size: 18, weight: .semibold, design: .rounded))
                                                .foregroundColor(.purple)
                                        }
                                        
                                        Spacer(minLength: 0)
                                    }
                                    .frame(maxWidth: .infinity)
                                    
                                    // Fat
                                    HStack(alignment: .top, spacing: 12) {
                                        ZStack {
                                            Circle()
                                                .fill(Color.pink.opacity(0.2))
                                                .frame(width: 40, height: 40)
                                            
                                            Image(systemName: "drop.fill")
                                                .foregroundColor(.pink)
                                        }
                                        
                                        VStack(alignment: .leading, spacing: 0) {
                                            Text("Fat")
                                                .font(.system(size: 16, weight: .regular))
                                            
                                            Text("\(Int(foodManager.fatConsumed))g")
                                                .font(.system(size: 18, weight: .semibold, design: .rounded))
                                                .foregroundColor(.pink)
                                        }
                                        
                                        Spacer(minLength: 0)
                                    }
                                    .frame(maxWidth: .infinity)
                                }
                            }
                            .padding()
                            .background(Color("iosnp"))
                            .cornerRadius(12)
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 8)
                        
                        // Show food scanning card if analysis is in progress
                        if foodManager.isScanningFood {
                            FoodGenerationCard()
                                .padding(.horizontal)
                                .transition(.opacity)
                                .environmentObject(foodManager)
                        }
                        
                        // Regular food analysis card (for AI generation)
                        else if foodManager.isAnalyzingFood {
                            FoodAnalysisCard()
                                .padding(.horizontal)
                                .transition(.opacity)
                        }
                        
            
                        
                        // Loading state for logs
                        if foodManager.isLoadingDateLogs {
                            VStack(spacing: 20) {
                                ProgressView()
                                    .frame(maxWidth: .infinity, alignment: .center)
                                Text("Loading logs...")
                                    .foregroundColor(.secondary)
                            }
                            .padding(.top, 30)
                            .frame(maxWidth: .infinity)
                        }
                        // Error state
                        else if let error = foodManager.dateLogsError {
                            VStack(spacing: 20) {
                                Image(systemName: "exclamationmark.triangle")
                                    .font(.system(size: 30))
                                    .foregroundColor(.orange)
                                Text("Error loading logs")
                                    .font(.headline)
                                Text(error.localizedDescription)
                                    .font(.caption)
                                    .multilineTextAlignment(.center)
                                    .foregroundColor(.secondary)
                                Button("Try Again") {
                                    foodManager.fetchLogsByDate(date: foodManager.selectedDate)
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(Color.accentColor)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                        }
                        // Empty state
                        else if foodManager.currentDateLogs.isEmpty {
                            VStack(spacing: 20) {
                                Image(systemName: "fork.knife")
                                    .font(.system(size: 50))
                                    .foregroundColor(.gray)
                                Text("No logs for this day")
                                    .font(.headline)
                                Text("Tap the 'Log Food' button to add your meals")
                                    .font(.caption)
                                    .multilineTextAlignment(.center)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.top, 50)
                            .frame(maxWidth: .infinity)
                        }
                        // Logs for the selected date
                        else {
                            VStack(alignment: .leading, spacing: 10) {
                                // Logs section header
                                Text("Recent Logs")
                                    .font(.title)
                                    .fontWeight(.bold)
                                                                        .padding(.horizontal)
                                
                                LazyVStack(spacing: 12) {
                                    ForEach(foodManager.currentDateLogs) { log in
                                        LogRow(log: log)
                                            .padding(.horizontal)
                                            .transition(.asymmetric(
                                                insertion: .scale(scale: 0.9).combined(with: .opacity).animation(.spring(response: 0.3, dampingFraction: 0.7)),
                                                removal: .opacity.animation(.easeOut(duration: 0.2))
                                            ))
                                            .id(log.id) // Ensure proper animation by giving each row a stable identity
                                    }
                                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: foodManager.currentDateLogs.map { $0.id })
                                }
                            }
                        }
                        
                        Spacer(minLength: 80) // Space for tab bar
                    }
                    .padding(.vertical)
                    .animation(.default, value: foodManager.isLoading)
                    .animation(.default, value: foodManager.isScanningFood)
                }
                
                // AI Generation Success Toast
                if foodManager.showAIGenerationSuccess, let food = foodManager.aiGeneratedFood {
                    VStack{
                        Spacer()
                        BottomPopup(message: "Food logged")
                            .padding(.bottom, 55)
                    }
                    .zIndex(100)
                    .transition(.opacity)
                    .animation(.spring(), value: foodManager.showAIGenerationSuccess)
                }
                // Regular Log Success Toast 
                else if foodManager.showLogSuccess, let item = foodManager.lastLoggedItem {
                    VStack{
                        Spacer()
                        BottomPopup(message: "\(item.name) logged")
                            .padding(.bottom, 55) //bot 
                    }
                    .zIndex(100)
                    .transition(.opacity)
                    .animation(.spring(), value: foodManager.showLogSuccess)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // Use a ToolbarItemGroup to properly center the date navigation controls
                ToolbarItemGroup(placement: .principal) {
                    HStack(spacing: 10) {
                        Button(action: {
                            foodManager.goToPreviousDay()
                        }) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(.primary)
                        }
                        
                        Button(action: {
                            showDatePicker()
                        }) {
                            Text(dateNavigationTitle)
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(.primary)
                        }
                        
                        Button(action: {
                            // Only allow moving forward if we're not on today
                            if !isToday {
                                foodManager.goToNextDay()
                            }
                        }) {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(isToday ? .gray : .primary)
                        }
                        .disabled(isToday)
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 16) {
                        // Refresh button
                        Button(action: {
                            foodManager.reloadCurrentDateLogs()
                        }) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.accentColor)
                        }
                        
                        // Calendar button
                        Button(action: {
                            showDatePicker()
                        }) {
                            Image(systemName: "calendar")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.accentColor)
                        }
                    }
                }
            }
            .onAppear {
                isTabBarVisible.wrappedValue = true
                print("📊 DashboardView appeared")
                
                if !viewModel.email.isEmpty {
                    // Initialize food manager with user email
                    foodManager.initialize(userEmail: viewModel.email)
                    
                    // Fetch logs for today if not already loaded
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        if foodManager.currentDateLogs.isEmpty && !foodManager.isLoadingDateLogs {
                            print("📅 Fetching logs for today")
                            // Use reloadCurrentDateLogs instead of fetchLogsByDate for more reliability
                            foodManager.reloadCurrentDateLogs()
                        } else {
                            // If today's logs are already loaded, make sure we preload adjacent days
                            foodManager.preloadAdjacentDays(silently: true)
                        }
                    }
                } else {
                    print("⚠️ User email is empty, cannot initialize food manager")
                }
            }
            .onChange(of: foodManager.scanningFoodError) { error in
                if let _ = error {
                    showScanningErrorAlert = true
                }
            }
            .alert("Logging Error", isPresented: $showScanningErrorAlert) {
                Button("OK", role: .cancel) { 
                    foodManager.scanningFoodError = nil
                }
            } message: {
                Text(foodManager.scanningFoodError ?? "Failed to analyze food image")
            }
            .sheet(isPresented: $showDatePickerSheet, onDismiss: onDateSelected) {
                DatePickerView(selectedDate: $selectedDate, isPresented: $showDatePickerSheet)
            }
        }
        .navigationViewStyle(StackNavigationViewStyle()) // Use stack style to prevent side bar on iPad
    }
    
    // Date navigation properties
    private var isToday: Bool {
        Calendar.current.isDateInToday(foodManager.selectedDate)
    }
    
    private var isYesterday: Bool {
        Calendar.current.isDateInYesterday(foodManager.selectedDate)
    }
    
    private var dateNavigationTitle: String {
        if isToday {
            return "Today"
        } else if isYesterday {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE, MMM d"
            return formatter.string(from: foodManager.selectedDate)
        }
    }
    
    // Date navigation method
    private func moveToDate(byDays days: Int) {
        if let newDate = Calendar.current.date(byAdding: .day, value: days, to: selectedDate) {
            selectedDate = newDate
            // Refresh logs for the selected date
            // TODO: Add filter logic for showing logs from selected date
        }
    }
    
    // Helper function to get the display name for a log
    private func getLogName(_ log: CombinedLog) -> String {
        switch log.type {
        case .food:
            return log.food?.displayName ?? "Food"
        case .meal:
            return log.meal?.title ?? "Meal"
        case .recipe:
            return log.recipe?.title ?? "Recipe"
        }
    }
    
    // Helper function to get the date for a log
    private func getLogDate(_ log: CombinedLog) -> Date? {
        return log.scheduledAt
    }
    
    // Helper function to format a date
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    // Show date picker sheet
    private func showDatePicker() {
        selectedDate = foodManager.selectedDate
        showDatePickerSheet = true
    }
    
    // Update view after picking a date from the date picker
    private func onDateSelected() {
        // Check if the selected date is today
        if Calendar.current.isDateInToday(selectedDate) {
            // Use goToToday to ensure fresh data when returning to today
            foodManager.goToToday()
        } else {
            // For other dates, use normal fetch
            foodManager.fetchLogsByDate(date: selectedDate)
        }
    }
}

// Food analysis card that shows the animated analysis UI
struct FoodAnalysisCard: View {
    @EnvironmentObject var foodManager: FoodManager
    @State private var animateProgress = false
    
    var analysisTitle: String {
        if !foodManager.loadingMessage.isEmpty {
            return foodManager.loadingMessage
        }
        
        switch foodManager.analysisStage {
        case 0: return "Analyzing Food..."
        case 1: return "Separating Ingredients..."
        case 2: return "Breaking down macros..."
        case 3: return "Finishing Analysis..."
        default: return "Analyzing Food..."
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(analysisTitle)
                .font(.headline)
                .fontWeight(.semibold)
                .transition(.opacity)
                .animation(.easeInOut, value: foodManager.analysisStage)
            
            // Progress bars
            VStack(spacing: 12) {
                ProgressBar(width: animateProgress ? 0.9 : 0.3, delay: 0)
                ProgressBar(width: animateProgress ? 0.7 : 0.5, delay: 0.2)
                ProgressBar(width: animateProgress ? 0.8 : 0.4, delay: 0.4)
            }
            
            Text("We'll notify you when done!")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 10)
        }
        .padding()
        .background(Color("iosnp"))
        .cornerRadius(12)
        .onAppear {
            startAnimation()
        }
        .onChange(of: foodManager.analysisStage) { _ in
            // Restart animation for each stage
            startAnimation()
        }
    }
    
    private func startAnimation() {
        animateProgress = false
        withAnimation(.easeIn(duration: 0.3)) {
            animateProgress = true
        }
        
        // Cycle the animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(.easeOut(duration: 0.3)) {
                animateProgress = false
            }
        }
    }
}

// Animated progress bar component
struct ProgressBar: View {
    var width: CGFloat
    var delay: Double
    
    @State private var animate = false
    
    var body: some View {
        GeometryReader { geometry in
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.gray.opacity(0.2))
                .frame(height: 8)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.accentColor)
                        .frame(width: geometry.size.width * width, height: 8, alignment: .leading)
                )
        }
        .frame(height: 8)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                withAnimation(.spring(response: 0.6)) {
                    animate = true
                }
            }
        }
    }
}

// Date picker view for the sheet
struct DatePickerView: View {
    @Binding var selectedDate: Date
    @Binding var isPresented: Bool
    
    var body: some View {
        NavigationView {
            VStack {
                DatePicker(
                    "Select a date",
                    selection: $selectedDate,
                    in: ...Date(),
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .padding()
            }
            .navigationTitle("Choose Date")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        isPresented = false
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
            }
        }
    }
}

// MARK: - LogRow View
struct LogRow: View {
    let log: CombinedLog
    @State private var isHighlighted = false
    
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            // Icon based on meal type
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.1))
                    .frame(width: 45, height: 45)
                
                Image(systemName: mealTypeIcon)
                    .font(.system(size: 18))
                    .foregroundColor(.accentColor)
            }
            
            // Food/Meal info
            VStack(alignment: .leading, spacing: 4) {
                Text(displayName)
                    .font(.system(size: 16, weight: .medium))
                    .lineLimit(1)
                
                HStack(spacing: 8) {
                    if let mealType = getMealTypeLabel() {
                        Text(mealType)
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                    
                    if let mealType = getMealTypeLabel(), let timeLabel = getTimeLabel() {
                        Text("•")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                    
                    if let timeLabel = getTimeLabel() {
                        Text(timeLabel)
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            // Calories
            HStack(spacing: 4) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.orange)
                Text("\(Int(log.displayCalories))")
                    .font(.system(size: 15, weight: .medium))
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color("iosnp"))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.accentColor.opacity(isHighlighted ? 0.5 : 0), lineWidth: 2)
                )
        )
        .cornerRadius(12)
        .onAppear {
            // Apply highlight animation for new (optimistic) logs
            if log.isOptimistic {
                withAnimation(.easeInOut(duration: 0.5).repeatCount(3, autoreverses: true)) {
                    isHighlighted = true
                }
                
                // Remove highlight after animation finishes
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    withAnimation {
                        isHighlighted = false
                    }
                }
            }
        }
    }
    
    // Helper properties
    private var displayName: String {
        switch log.type {
        case .food:
            return log.food?.displayName ?? "Food"
        case .meal:
            return log.meal?.title ?? "Meal"
        case .recipe:
            return log.recipe?.title ?? "Recipe"
        }
    }
    
    private var mealTypeIcon: String {
        let mealType = log.mealType?.lowercased() ?? ""
        
        switch mealType {
        case "breakfast":
            return "sunrise.fill"
        case "lunch":
            return "sun.max.fill"
        case "dinner":
            return "moon.stars.fill"
        case "snack":
            return "carrot.fill"
        default:
            return "fork.knife"
        }
    }
    
    private func getMealTypeLabel() -> String? {
        return log.mealType
    }
    
    private func getTimeLabel() -> String? {
        guard let date = log.scheduledAt else { return nil }
        
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - LogSuccessCard View
struct LogSuccessCard: View {
    @EnvironmentObject var foodManager: FoodManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            
            // Success content
            if let (name, calories) = foodManager.lastLoggedItem {
                HStack {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(name)
                            .font(.system(size: 16, weight: .medium))
                        
                        Text("Added to your food log")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .foregroundColor(.orange)
                            .font(.system(size: 12))
                        Text("\(Int(calories))")
                            .font(.system(size: 16, weight: .medium))
                    }
                }
            }
        }
        .padding()
        .background(Color("iosnp"))
        .cornerRadius(12)
    }
}

