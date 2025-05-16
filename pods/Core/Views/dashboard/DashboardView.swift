import SwiftUI
import HealthKit

struct DashboardView: View {

    // ─── Shared app-wide state ──────────────────────────────────────────────
    @EnvironmentObject private var onboarding: OnboardingViewModel
    @EnvironmentObject private var foodMgr   : FoodManager
    @Environment(\.isTabBarVisible) private var isTabBarVisible
    @EnvironmentObject var vm: DayLogsViewModel
    
    // ─── Health data state ───────────────────────────────────────────────────
    @StateObject private var healthViewModel = HealthKitViewModel()

    // ─── Local UI state ─────────────────────────────────────────────────────
    @State private var showDatePicker = false
    @State private var showWaterLogSheet = false
    @State private var showHealthPermissionAlert = false

    // ─── Quick helpers ──────────────────────────────────────────────────────
    private var isToday     : Bool { Calendar.current.isDateInToday(vm.selectedDate) }
    private var isYesterday : Bool { Calendar.current.isDateInYesterday(vm.selectedDate) }

  private var calorieGoal : Double { vm.calorieGoal }
private var remainingCal: Double { vm.remainingCalories }


    private var navTitle: String {
        if isToday      { return "Today" }
        if isYesterday  { return "Yesterday" }
        let f = DateFormatter(); f.dateFormat = "EEEE, MMM d"
        return f.string(from: vm.selectedDate)
    }

    // ────────────────────────────────────────────────────────────────────────
    // MARK: -- View body
    // ────────────────────────────────────────────────────────────────────────

    var body: some View {
        NavigationView {
            ZStack {
                Color("iosbg2").ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {

                        nutritionSummaryCard            // ① macros + remaining kcals
                            // .padding(.trailing, -10) 
                                 .padding(.horizontal, -16) 
                     

                        if foodMgr.isAnalyzingFood {
                            FoodAnalysisCard()
                                .padding(.horizontal)
                                .transition(.opacity)
                        }

                        if foodMgr.isScanningFood {
                            FoodGenerationCard()
                                .padding(.horizontal)
                                .transition(.opacity)
                        }

                        // ② list / loading / error / empty states
                        Group {
                            if vm.isLoading        { loadingState }
                            else if let err = vm.error   { errorState(err) }
                            else if vm.logs.isEmpty      { emptyState }
                            else                        { logsList }
                        }
                        .animation(.default, value: vm.logs)

                        Spacer(minLength: 80)            // room for the tab bar
                    }
                    .padding(.top, 8) // 8px space between navbar and first card
                    .padding(.bottom)
                }

                   if foodMgr.showAIGenerationSuccess, let food = foodMgr.aiGeneratedFood {
        VStack {
          Spacer()
          BottomPopup(message: "Food logged")
            .padding(.bottom, 55)
        }
        .zIndex(1)
        .transition(.opacity)
        .animation(.spring(), value: foodMgr.showAIGenerationSuccess)
      }
      else if foodMgr.showLogSuccess, let item = foodMgr.lastLoggedItem {
        VStack {
          Spacer()
          BottomPopup(message: "\(item.name) logged")
            .padding(.bottom, 55)
        }
        .zIndex(1)
        .transition(.opacity)
        .animation(.spring(), value: foodMgr.showLogSuccess)
      }
    }
            
                 
            
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .sheet(isPresented: $showDatePicker) {
                DatePickerSheet(date: $vm.selectedDate,
                                isPresented: $showDatePicker)
            }
            .onAppear {
                configureOnAppear() 
                // Initialize food manager with user email
                foodMgr.initialize(userEmail: onboarding.email)
                
                // Check health permissions and request if needed
                checkHealthPermissions()
                
                // Load health data for the selected date
                healthViewModel.reloadHealthData(for: vm.selectedDate)
            }
            .alert("Health Permissions Required", isPresented: $showHealthPermissionAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Allow Access") {
                    healthViewModel.requestHealthKitPermissions()
                }
            } message: {
                Text("To display your health data on the dashboard, Pods needs access to Apple Health. Your data is kept private and never leaves your device.")
            }
            .onChange(of: vm.selectedDate) { newDate in
                vm.loadLogs(for: newDate)   // fetch fresh ones
                
                // Update health data for the selected date
                healthViewModel.reloadHealthData(for: newDate)
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("WaterLoggedNotification"))) { _ in
                // Refresh health data when water is logged (for current selected date)
                healthViewModel.reloadHealthData(for: vm.selectedDate)
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("HealthDataAvailableNotification"))) { _ in
                // Refresh health data when permissions are granted
                healthViewModel.reloadHealthData(for: vm.selectedDate)
            }

        }
        .navigationViewStyle(.stack)
    }
}

// ────────────────────────────────────────────────────────────────────────────
// MARK: -- Sub-views
// ────────────────────────────────────────────────────────────────────────────
private extension DashboardView {
 
    // ① Nutrition summary ----------------------------------------------------
    var nutritionSummaryCard: some View {
        VStack(spacing: 0) {
            GeometryReader { geometry in
                TabView {
                    // Page 1: Original cards
                    VStack(spacing: 10) {
                        remainingCaloriesCard
                        macrosCard

                    }
                    .padding(.trailing, 16) // Add horizontal padding for spacing between pages
                         .padding(.leading, 16)
                    .frame(width: geometry.size.width, height: geometry.size.height, alignment: .top)
                    .padding(.top, 8)
                    
                    // Page 2: Health data summary
                    VStack(spacing: 10) {
                        macroCirclesCard
                        healthSummaryCard
                    }
                    .padding(.leading, 16)
                    .padding(.trailing, 16) // Add horizontal padding for spacing between pages
                       
                    .frame(width: geometry.size.width, height: geometry.size.height, alignment: .top)
                    .padding(.top, 8)
                    
                    // Page 3: Health Data
                    VStack(spacing: 10) {
                        sleepCard
                        .padding(.bottom, 0)

                            // Match the healthSummaryCard approach (uses content height + padding)
                        HStack(spacing: 10) {
                            heightCard
                            weightCard
                        }
                          .frame(height: 100)
                    }
                    .padding(.leading, 16)
                    .padding(.trailing, 16) // Add horizontal padding for spacing between pages
                    
                    .frame(width: geometry.size.width, height: geometry.size.height, alignment: .top)
                    .padding(.top, 8)
                }
                .frame(height: 300) // Enough height so cards fully visible, with 8px above page dots
                .tabViewStyle(PageTabViewStyle())
                .indexViewStyle(PageIndexViewStyle(backgroundDisplayMode: .always))
            }
            .frame(height: 300) // Set the same height for GeometryReader
        }
        .padding(.horizontal)
    }
    
    // Remaining calories card
    var remainingCaloriesCard: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Remaining")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.secondary)

                Text("\(Int(remainingCal))cal")
                    .font(.system(size: 32, weight: .bold))
            }

            Spacer()

            ZStack {
                Circle()
                    .stroke(lineWidth: 10)
                    .opacity(0.2)
                    .foregroundColor(.green)

                Circle()
                    .trim(from: 0,
                          to: CGFloat(1 - (remainingCal / calorieGoal)))
                    .stroke(style: StrokeStyle(lineWidth: 10,
                                               lineCap: .round))
                    .foregroundColor(.green)
                    .rotationEffect(.degrees(270))
                    .animation(.linear, value: remainingCal)
            }
            .frame(width: 60, height: 60)
        }
        .frame(height: 85) // Reduced height
        .padding(.vertical, 12) // Slightly reduced vertical padding
        .padding(.horizontal)
        .background(Color("iosnp"))
        .cornerRadius(12)
    }
    
    // Macros card as a separate component
    var macrosCard: some View {
        VStack(spacing: 16) {
            macroRow(left:  ("Calories", vm.totalCalories,  "flame.fill",    Color("brightOrange")),
                    right: ("Protein",  vm.totalProtein,   "fish.fill",        .blue))
            macroRow(left:  ("Carbs",     vm.totalCarbs,   "laurel.leading", Color("darkYellow")),
                    right: ("Fat",       vm.totalFat,      "drop.fill",     .pink))
        }
        .padding()
        .background(Color("iosnp"))
        .cornerRadius(12)
    }

    // Macro Circles Card for page 2
    var macroCirclesCard: some View {
        HStack(spacing: 8) {
            // Protein Circle
            macroCircle(
                title: "Protein",
                value: vm.totalProtein,
                goal: proteinGoal,
                color: .blue
            )
            
            // Carbs Circle
            macroCircle(
                title: "Carbs",
                value: vm.totalCarbs,
                goal: carbsGoal,
                color: Color("darkYellow")
            )
            
            // Fat Circle
            macroCircle(
                title: "Fat",
                value: vm.totalFat,
                goal: fatGoal,
                color: .pink
            )
        }
        .frame(height: 85) // Reduced height
        .padding(.vertical, 12) // Slightly reduced vertical padding
        .padding(.horizontal)
        .background(Color("iosnp"))
        .cornerRadius(12)
    }

    // Helper function to create each macro circle
    func macroCircle(title: String, value: Double, goal: Double, color: Color) -> some View {
        let percentage = min(value / max(goal, 1) * 100, 100)
        
        return VStack(spacing: 1) {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.primary)
                .padding(.top, 2)
                .padding(.bottom, 6) // Added bottom padding for the label
            
            ZStack {
                // Background circle
                Circle()
                    .stroke(lineWidth: 6)
                    .opacity(0.2)
                    .foregroundColor(color)
                
                // Progress circle
                Circle()
                    .trim(from: 0, to: CGFloat(percentage / 100))
                    .stroke(style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .foregroundColor(color)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut, value: percentage)
                
                // Percentage and grams inside the circle
                VStack(spacing: 0) {
                    Text("\(Int(percentage))%")
                        .font(.system(size: 13, weight: .bold))
                    
                    Text("\(Int(value))/\(Int(goal))g")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 65, height: 65) // Larger circles to fill space
        }
        .frame(maxWidth: .infinity)
    }

    // Placeholder card template for carousel
    func placeholderCard(title: String, subtitle: String, color: Color) -> some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.secondary)

                Text(subtitle)
                    .font(.system(size: 32, weight: .bold))
            }

            Spacer()

            ZStack {
                Circle()
                    .fill(color.opacity(0.2))
                    .frame(width: 60, height: 60)
                
                Image(systemName: title == "Coming Soon" ? "hourglass" : "checkmark")
                    .font(.system(size: 24))
                    .foregroundColor(color)
            }
        }
        .padding()
        .background(Color("iosnp"))
        .cornerRadius(12)
    }

    // Sleep card for page 3
    var sleepCard: some View {
        // Debug print
        let _ = print("Sleep data: \(healthViewModel.sleepHours) hours, \(healthViewModel.sleepMinutes) minutes")
        
        return HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "bed.double.fill")
                        .foregroundColor(.teal)
                        .font(.system(size: 16))
                    
                    Text("Sleep")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.teal)
                }
                Spacer()
                 .frame(height: 30)
                Text("Time Asleep")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(.secondary)
                
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("\(Int(healthViewModel.sleepHours))")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    
                    Text("hr")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.secondary)
                        .padding(.trailing, 4)
                    
                    Text("\(healthViewModel.sleepMinutes)")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    
                    Text("min")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            ZStack {
                Circle()
                    .stroke(lineWidth: 10)
                    .opacity(0.2)
                    .foregroundColor(.teal)

                Circle()
                    .trim(from: 0,
                          to: CGFloat(healthViewModel.sleepProgress))
                    .stroke(style: StrokeStyle(lineWidth: 10,
                                               lineCap: .round))
                    .foregroundColor(.teal)
                    .rotationEffect(.degrees(270))
                    .animation(.linear, value: healthViewModel.sleepProgress)
            }
            .frame(width: 60, height: 60)
        }
        // .frame(height: 100)
        .padding(.vertical, 12) // Match macroCirclesCard padding
        .padding(.horizontal)
        .background(Color("iosnp"))
        .cornerRadius(12)
    }

    // ② Loading / error / empty / list --------------------------------------
    var loadingState: some View {
        VStack(spacing: 20) {
            ProgressView()
            Text("Loading logs…").foregroundColor(.secondary)
        }
        .padding(.top, 40)
        .frame(maxWidth: .infinity)
    }

    func errorState(_ err: Error) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 30))
                .foregroundColor(.orange)
            Text("Error loading logs").font(.headline)
            Text(err.localizedDescription)
                .font(.caption)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            Button("Try again") { vm.loadLogs(for: vm.selectedDate) }
                .padding(.horizontal, 20).padding(.vertical, 10)
                .background(Color.accentColor).foregroundColor(.white)
                .cornerRadius(8)
        }
        .padding()
        .frame(maxWidth: .infinity)
    }

    var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "fork.knife")
                .font(.system(size: 50))
                .foregroundColor(.gray)
            Text("No logs for this day").font(.headline)
            Text("Tap Log Food to add your meals.")
                .font(.caption)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
        }
        .padding(.top, 50)
        .frame(maxWidth: .infinity)
    }

    var logsList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Logs")
                .font(.title)
                .fontWeight(.bold)
            LazyVStack(spacing: 12) {
                ForEach(vm.logs) { log in
                    LogRow(log: log)
                        .id(log.id)
                }
            }
        }
        .padding(.horizontal)
    }

    // ③ Toolbar --------------------------------------------------------------
@ToolbarContentBuilder
    var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .principal) {
            HStack(spacing: 10) {
                Button {
                    vm.selectedDate.addDays(-1)
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.primary)
                }

                Button {
                    showDatePicker = true
                } label: {
                    Text(navTitle)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.primary)
                }

                Button {
                    if !isToday {
                        vm.selectedDate.addDays(+1)
                    }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(isToday ? .gray : .primary)
                }
                .disabled(isToday)
            }
        }

        ToolbarItem(placement: .navigationBarTrailing) {
            HStack(spacing: 16) {
                Button {
                    vm.loadLogs(for: vm.selectedDate)
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.accentColor)
                }

                Button {
                    showDatePicker = true
                } label: {
                    Image(systemName: "calendar")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.accentColor)
                }
            }
        }
    }
}

// ────────────────────────────────────────────────────────────────────────────
// MARK: -- Helpers
// ────────────────────────────────────────────────────────────────────────────

private extension DashboardView {
    /// Initialise e-mail + first load
   
    func configureOnAppear() {
        isTabBarVisible.wrappedValue = true

        if vm.email.isEmpty, !onboarding.email.isEmpty {
            vm.setEmail(onboarding.email)


        }
        if vm.logs.isEmpty {
            vm.loadLogs(for: vm.selectedDate)
        }
    }
    
    /// Check HealthKit permissions and show prompt if needed
    func checkHealthPermissions() {
        let healthStore = HealthKitManager.shared
        
        // Only try if HealthKit is available on the device
        guard healthStore.isHealthDataAvailable else { return }
        
        // Check if the user has previously declined permissions
        if !healthStore.isAuthorized {
            // Show the permission alert
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.showHealthPermissionAlert = true
            }
        }
    }
}

private extension Date {
    mutating func addDays(_ d: Int) {
        self = Calendar.current.date(byAdding: .day,
                                     value: d,
                                     to: self) ?? self
    }
}


struct DatePickerSheet: View {
    @Binding var date       : Date
    @Binding var isPresented: Bool
    var body: some View {
        NavigationView {
            VStack {
                DatePicker("Select a date",
                           selection: $date,
                           in: ...Date(),
                           displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .padding()
            }
            .navigationTitle("Choose Date")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { isPresented = false }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }
                }
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

@ViewBuilder
func macroRow(left: (String, Double, String, Color),
                  right: (String, Double, String, Color)) -> some View {
    HStack(spacing: 0) {
        macroCell(title: left.0, value: left.1,
                  sf: left.2, colour: left.3)
        macroCell(title: right.0, value: right.1,
                  sf: right.2, colour: right.3)
    }
}

@ViewBuilder
func macroCell(title: String, value: Double,
                   sf: String, colour: Color) -> some View {
    HStack(alignment: .top, spacing: 12) {
        ZStack {
            Circle().fill(colour.opacity(0.2))
                    .frame(width: 40, height: 40)
            Image(systemName: sf).foregroundColor(colour)
        }
        VStack(alignment: .leading, spacing: 0) {
            Text(title).font(.system(size: 16))
            Text("\(Int(value))\(title == "Calories" ? "" : "g")")
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundColor(colour)
        }
        Spacer(minLength: 0)
    }
    .frame(maxWidth: .infinity)
}

// Calculated macro goals based on total calories
private extension DashboardView {
    var proteinGoal: Double {
        return calorieGoal * 0.3 / 4 // 30% of calories from protein (4 calories per gram)
    }
    
    var carbsGoal: Double {
        return calorieGoal * 0.45 / 4 // 45% of calories from carbs (4 calories per gram)
    }
    
    var fatGoal: Double {
        return calorieGoal * 0.25 / 9 // 25% of calories from fat (9 calories per gram)
    }
}

private extension DashboardView {
    // Health summary card for page 2
    var healthSummaryCard: some View {
        VStack(spacing: 16) {
            // First row: Calories Burned and Water
            HStack(spacing: 0) {
                // Calories Burned
                healthMetricCell(
                    title: "Calories Burned",
                    value: Int(healthViewModel.activeEnergy),
                    unit: "",
                    systemImage: "flame.fill",
                    color: Color("brightOrange")
                )
                
                            // Water with add button
            waterMetricCell(
                title: "Water",
                value: String(format: "%.1f", healthViewModel.waterIntake),
                unit: "L",
                systemImage: "drop.fill",
                color: .blue
            )
            }
            
            // Second row: Step Count and Step Distance
            HStack(spacing: 0) {
                // Step Count
                healthMetricCell(
                    title: "Steps",
                    value: Int(healthViewModel.stepCount),
                    unit: "",
                    systemImage: "figure.walk",
                    color: .green
                )
                
                            // Step Distance from HealthKit
            healthMetricCell(
                title: "Distance",
                value: String(format: "%.2f", healthViewModel.distance),
                unit: "mi",
                systemImage: "figure.walk.motion",
                color: .purple
            )
            }
        }
        .padding()
        .background(Color("iosnp"))
        .cornerRadius(12)
    }

    /// Re‑usable metric cell used by healthSummaryCard
    func healthMetricCell(title: String, value: Any, unit: String, systemImage: String, color: Color) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.2))
                    .frame(width: 40, height: 40)
                
                Image(systemName: systemImage)
                    .foregroundColor(color)
            }
            
            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .font(.system(size: 16))
                if let intValue = value as? Int {
                    Text("\(intValue)\(unit)")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundColor(color)
                } else if let stringValue = value as? String {
                    Text("\(stringValue)\(unit)")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundColor(color)
                }
            }
            
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
    }

    /// Special metric cell for water with add button
    func waterMetricCell(title: String, value: Any, unit: String, systemImage: String, color: Color) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.2))
                    .frame(width: 40, height: 40)
                
                Image(systemName: systemImage)
                    .foregroundColor(color)
            }
            
            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .font(.system(size: 16))
                if let intValue = value as? Int {
                    Text("\(intValue)\(unit)")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundColor(color)
                } else if let stringValue = value as? String {
                    Text("\(stringValue)\(unit)")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundColor(color)
                }
            }
            
            Spacer(minLength: 0)
            
            // Add water button
            Button(action: {
                showWaterLogSheet = true
            }) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(color)
            }
            .padding(.trailing, 4)
        }
        .frame(maxWidth: .infinity)
        .sheet(isPresented: $showWaterLogSheet) {
            LogWaterView()
                .onDisappear {
                    // Refresh health data when sheet is dismissed
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        healthViewModel.reloadHealthData(for: vm.selectedDate)
                    }
                }
        }
    }
}



private extension DashboardView {
    // Height card for page 3
    var heightCard: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "figure")
                        .foregroundColor(.purple)
                        .font(.system(size: 16))
                    Text("Height")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.purple)
                }
                Spacer()
                if vm.height > 0 {
                    let feet = Int(vm.height / 30.48) // convert cm to feet
                    let remainingCm = vm.height.truncatingRemainder(dividingBy: 30.48)
                    let inches = Int(remainingCm / 2.54) // convert remainder to inches
                    Text("\(feet)' \(inches)\"")
                        .font(.system(size: 26, weight: .semibold, design: .rounded))
                        .foregroundColor(.primary)
                } else {
                    Text("No data")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundColor(.gray)
                }
            }
            Spacer()
            Button(action: {
                print("Adding new height measurement")
            }) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.purple)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color("iosnp"))
        .cornerRadius(12)
    }

    // Weight card for page 3
    var weightCard: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "figure")
                        .foregroundColor(.purple)
                        .font(.system(size: 16))
                    Text("Weight")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.purple)
                }
                Spacer()
                let weightInLbs = Int(vm.weight * 2.20462)
                HStack(spacing:0){
                    Text("\(weightInLbs)")
                    .font(.system(size: 26, weight: .semibold, design: .rounded))
                    .foregroundColor(.primary)
                     Text("lb")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.secondary)
                }
                
            }
            Spacer()
            Button(action: {
                print("Adding new weight measurement")
            }) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.purple)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color("iosnp"))
        .cornerRadius(12)
    }
}
