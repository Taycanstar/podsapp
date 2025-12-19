//
//  DayLogsViewModel.swift
//  Pods
//
//  Created by Dimi Nunez on 5/11/25.
//

import Foundation
import SwiftUI
import Combine


struct DailyNutritionSummary: Identifiable, Equatable {
  let date: Date
  let calories: Double
  let protein: Double
  let carbs: Double
  let fat: Double

  var id: Date { date }
}

struct EnergyBalancePoint: Identifiable, Equatable {
  let date: Date
  let intake: Double
  let expenditure: Double

  var id: Date { date }
  var balance: Double { intake - expenditure }
}

struct HabitConsistencyData {
  let title: String
  let weeklyCompleted: Int
  let weeklyTotal: Int
  let gridLevels: [Int]
}

@MainActor
final class DayLogsViewModel: ObservableObject {
      @Published var logs         : [CombinedLog] = [] {
    didSet {
      recalculateTotals()
      refreshConsistency(force: true, refreshWeight: false)
    }
  }
  @Published var calorieGoal      : Double = 2_000
  @Published var proteinGoal      : Double = 150
  @Published var carbsGoal        : Double = 200
  @Published var fatGoal          : Double = 70
  @Published var remainingCalories: Double = 2_000   // always ≥ 0
  @Published var hasAdvancedNutritionTargets: Bool = false
  @Published var nutritionGoalsVersion = UUID()
  @Published var isRefreshingNutritionGoals = false

  private var pendingByDate: [Date: [CombinedLog]] = [:]
  private var currentSnapshotDate: Date?
  @Published var error        : Error?
  @Published var isLoading    = false
  @Published var selectedDate = Date()

  private var lastEmail: String?
  private var lastLoadTimestamps: [Date: Date] = [:]
  private let logsRefreshInterval: TimeInterval = 60
  private var activeScheduledIds: Set<Int> = []
  private var scheduledPlaceholderIds: [Int: String] = [:]
  private var scheduledResolvedLogIds: [Int: String] = [:]
  private var hiddenScheduledIds: Set<Int> = []
  private var skippedScheduledDates: [Int: Date] = [:]
  private var localScheduledOverrides: [Int: ScheduledLogPreview] = [:]
  private var pendingNotificationReload = false
  private var lastExpenditureRefresh: Date?
  private let expenditureRefreshInterval: TimeInterval = 900
  private var lastHealthMetricsRefresh: Date?
  private let healthMetricsRefreshInterval: TimeInterval = 600
  private let metricsDebugFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd HH:mm"
    formatter.timeZone = .current
    return formatter
  }()

  // Daily totals
  @Published var totalCalories: Double = 0
  @Published var totalProtein : Double = 0
  @Published var totalCarbs   : Double = 0
  @Published var totalFat     : Double = 0
  
  // Computed property for total calories burned (HealthKit + AI activities)
  var totalCaloriesBurned: Double {
      // Get HealthKit active energy
      let healthKitCalories = healthViewModel?.activeEnergy ?? 0
      
      // Add AI activity calories from today's logs
      let aiActivityCalories = logs.reduce(0.0) { sum, log in
          guard log.type == .activity else { return sum }
          // Only count AI activities (not HealthKit activities)
          if let activityId = log.activityId, !activityId.contains("-") {
              // This is an AI activity (integer ID format)
              return sum + log.calories
          }
          return sum
      }
      
      return healthKitCalories + aiActivityCalories
  }
  
  // User measurements from onboarding
  @Published var height: Double = 0 // Height in cm
  @Published var weight: Double = 0 // Weight in kg
  @Published var desiredWeightKg: Double = 0 // Desired weight in kg
  @Published var desiredWeightLbs: Double = 0 // Desired weight in lbs
  
  // Water logs for the current day
  @Published var waterLogs: [WaterLogResponse] = []
  @Published var scheduledPreviews: [ScheduledLogPreview] = []
  @Published var expenditureSnapshot: NetworkManagerTwo.ExpenditureSnapshot?
  @Published var expenditureState: NetworkManagerTwo.ExpenditureState?
  @Published var expenditureHistory: [NetworkManagerTwo.ExpenditureSnapshot] = []
  @Published var isLoadingExpenditure = false
  @Published var expenditureErrorMessage: String?
  @Published var healthMetricsSnapshot: NetworkManagerTwo.HealthMetricsSnapshot?
  @Published var isLoadingHealthMetrics = false
  @Published var healthMetricsErrorMessage: String?
  @Published var weeklyNutritionSummaries: [DailyNutritionSummary] = []
  @Published var weightConsistency: HabitConsistencyData?
  @Published var foodConsistency: HabitConsistencyData?
  var energyBalanceWeek: [EnergyBalancePoint] {
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: Date())
    let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: today)?.start ?? today
    return energyBalancePoints(startingAt: startOfWeek, days: 7)
  }
  var energyBalanceMonth: [EnergyBalancePoint] {
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: Date())
    let monthStartComponents = calendar.dateComponents([.year, .month], from: today)
    let startOfMonth = calendar.date(from: monthStartComponents) ?? today
    let daysInMonth = calendar.range(of: .day, in: .month, for: today)?.count ?? 30
    return energyBalancePoints(startingAt: startOfMonth, days: daysInMonth)
  }

  
  // Navigation properties
  @Published var navigateToEditHeight: Bool = false
  @Published var navigateToEditWeight: Bool = false
  @Published var navigateToWeightData: Bool = false

  private let repository = DayLogsRepository.shared
  private let logNetwork = LogRepository()
  private let goalsStore = NutritionGoalsStore.shared
  private(set) var email = ""
  private weak var healthViewModel: HealthKitViewModel?
  private var cancellables: Set<AnyCancellable> = []
  private var notificationCancellables: Set<AnyCancellable> = []
  private var goalsStoreCancellable: AnyCancellable?
  private var consistencyTask: Task<Void, Never>?

  enum ScheduledLogAction: String {
    case log
    case skip
    case cancel

    var requestValue: String { rawValue }
  }

  init(email: String = "", healthViewModel: HealthKitViewModel? = nil) {
    self.email = email
    self.healthViewModel = healthViewModel
    clearPendingCache()
    observeGoalsStore()
    observeSyncNotifications()

    if !email.isEmpty {
      configureRepository(for: email)
      fetchNutritionGoals()
    }
  }

  func setEmail(_ newEmail: String) {
    email = newEmail
    lastEmail = newEmail
    fetchNutritionGoals()
    // Clear pending cache when switching users
    clearPendingCache()
    configureRepository(for: newEmail)
    refreshExpenditureData(force: true)
    healthMetricsSnapshot = nil
    lastHealthMetricsRefresh = nil
    weightConsistency = nil
    foodConsistency = nil
    refreshHealthMetrics(force: true, targetDate: selectedDate)
    refreshConsistency()
  }
  
  func preloadForStartup(email: String) {
    if lastEmail != email {
        setEmail(email)
    }

    let key = Calendar.current.startOfDay(for: selectedDate)
    if let lastLoad = lastLoadTimestamps[key], Date().timeIntervalSince(lastLoad) < logsRefreshInterval,
       !logs.isEmpty {
        return
    }

    loadLogs(for: selectedDate)
    refreshExpenditureData()
    refreshHealthMetrics(targetDate: selectedDate)
    if weightConsistency == nil || foodConsistency == nil {
        refreshConsistency()
    }
  }
  
  func setHealthViewModel(_ healthViewModel: HealthKitViewModel) {
    self.healthViewModel = healthViewModel
  }

  private func configureRepository(for email: String) {
    repository.configure(email: email)
    cancellables.removeAll()

    repository.$snapshots
      .receive(on: DispatchQueue.main)
      .sink { [weak self] snapshots in
        guard let self else { return }
        let key = Calendar.current.startOfDay(for: self.selectedDate)
        if let snapshot = snapshots[key] {
          self.applySnapshot(snapshot)
        }
      }
      .store(in: &cancellables)

    if let snapshot = repository.snapshot(for: selectedDate) {
      applySnapshot(snapshot)
    }
  }

  private func observeGoalsStore() {
    goalsStoreCancellable = goalsStore.$state
      .receive(on: DispatchQueue.main)
      .sink { [weak self] state in
        guard let self else { return }
        switch state {
        case .loading:
          self.isRefreshingNutritionGoals = true
        case .ready(let goals):
          self.isRefreshingNutritionGoals = false
          self.applyNutritionGoals(goals, persist: false)
        case .error:
          self.isRefreshingNutritionGoals = false
        case .idle:
          self.isRefreshingNutritionGoals = false
        }
      }
  }

  private func observeSyncNotifications() {
    NotificationCenter.default.publisher(for: .ouraSyncCompleted)
      .receive(on: DispatchQueue.main)
      .sink { [weak self] _ in
        guard let self else { return }
        self.refreshHealthMetrics(force: true, targetDate: self.selectedDate)
      }
      .store(in: &notificationCancellables)

    NotificationCenter.default.publisher(for: Notification.Name("WeightLoggedNotification"))
      .receive(on: DispatchQueue.main)
      .sink { [weak self] _ in
        self?.refreshConsistency(refreshWeight: true)
      }
      .store(in: &notificationCancellables)

    NotificationCenter.default.publisher(for: Notification.Name("FoodLogUpdated"))
      .receive(on: DispatchQueue.main)
      .sink { [weak self] _ in
        self?.refreshConsistency(force: true, refreshWeight: false)
      }
      .store(in: &notificationCancellables)

    NotificationCenter.default.publisher(for: Notification.Name("NutritionGoalsUpdatedNotification"))
      .receive(on: DispatchQueue.main)
      .sink { [weak self] _ in
        self?.fetchNutritionGoals(forceRefresh: true)
      }
      .store(in: &notificationCancellables)
  }

  // MARK: - Public Methods
  
  /// Force refresh nutrition goals from UserDefaults
  /// This ensures the ViewModel has the most up-to-date values
  func refreshNutritionGoals(forceRefresh: Bool = false) {
    fetchNutritionGoals(forceRefresh: forceRefresh)
  }


  // MARK: – Goal helpers ------------------------------------------------------
func fetchCalorieGoal() {
    // 1) Highest priority: explicit dailyCalorieGoal if non-zero
    if let g = UserDefaults.standard.value(forKey: "dailyCalorieGoal") as? Double, g > 0 {
        calorieGoal = g
    }
    // 2) Next: nutritionGoalsData if non-zero
    else if let data = UserDefaults.standard.data(forKey: "nutritionGoalsData"),
              let goals = try? JSONDecoder().decode(NutritionGoals.self, from: data),
              goals.calories > 0 {
        calorieGoal = goals.calories
    }
    // 3) Next: UserGoalsManager (may have been saved earlier); ignore zeros
    else if UserGoalsManager.shared.dailyGoals.calories > 0 {
        calorieGoal = Double(UserGoalsManager.shared.dailyGoals.calories)
    }
    // 4) Fallback: sensible default
    else {
        calorieGoal = 2000
    }
    remainingCalories = max(0, calorieGoal - totalCalories)
}

  private func applyNutritionGoals(_ goals: NutritionGoals, persist: Bool) {
    if goals.calories > 0 {
      calorieGoal = goals.calories
    }
    proteinGoal = goals.protein
    carbsGoal = goals.carbs
    fatGoal = goals.fat

    if let desiredKg = goals.desiredWeightKg {
      desiredWeightKg = desiredKg
      desiredWeightLbs = goals.desiredWeightLbs ?? (desiredKg * 2.20462)
    } else if let desiredLbs = goals.desiredWeightLbs {
      desiredWeightLbs = desiredLbs
      desiredWeightKg = desiredLbs / 2.20462
    }

    hasAdvancedNutritionTargets = !(goals.nutrients?.isEmpty ?? true)
    nutritionGoalsVersion = UUID()
    remainingCalories = max(0, calorieGoal - totalCalories)

    guard persist else { return }
    NutritionGoalsStore.shared.cache(goals: goals)
  }

  private func applyFallbackNutritionGoals() {
    let goals = UserGoalsManager.shared.dailyGoals
    proteinGoal = Double(goals.protein)
    carbsGoal = Double(goals.carbs)
    fatGoal = Double(goals.fat)
    hasAdvancedNutritionTargets = false
    remainingCalories = max(0, calorieGoal - totalCalories)
  }


  func processScheduledLog(
    _ preview: ScheduledLogPreview,
    action: ScheduledLogAction,
    placeholderIdentifier: String? = nil
  ) async throws {
    guard !email.isEmpty else { return }

    let timezoneOffset = TimeZone.current.secondsFromGMT() / 60
    let requestDate = Calendar.current.startOfDay(for: preview.targetDate)

    let response = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<NetworkManagerTwo.ProcessScheduledMealResponse, Error>) in
      NetworkManagerTwo.shared.processScheduledMealLog(
        userEmail: email,
        scheduledId: preview.id,
        action: action.requestValue,
        targetDate: requestDate,
        timezoneOffset: timezoneOffset
      ) { result in
        switch result {
        case .success(let payload):
          continuation.resume(returning: payload)
        case .failure(let error):
          continuation.resume(throwing: error)
        }
      }
    }

    guard response.status.lowercased() == "success" else {
      throw NetworkManagerTwo.NetworkError.serverError(message: "Unable to update scheduled log")
    }

    #if DEBUG
    print("[DayLogsVM] processScheduledLog response – id:\(preview.id) action:\(response.action) scheduleType:\(response.scheduleType) isActive:\(response.isActive) nextDate:\(String(describing: response.nextTargetDate))")
    #endif

    scheduledPreviews.removeAll { $0.id == preview.id }
    localScheduledOverrides.removeValue(forKey: preview.id)
    if action != .skip {
      skippedScheduledDates.removeValue(forKey: preview.id)
    }

    if action == .log {
      if let placeholderIdentifier {
        markPlaceholderSettled(identifier: placeholderIdentifier)
      }

      if let logType = response.logType,
         let loggedId = response.loggedLogId {
        scheduledResolvedLogIds[preview.id] = combinedIdentifier(for: logType, logId: loggedId)
      }

      if response.isActive {
        let updatedPreview = ScheduledLogPreview(
          id: preview.id,
          scheduleType: response.scheduleType,
          targetDate: response.nextTargetDate ?? preview.targetDate,
          targetTime: response.nextTargetTime ?? preview.targetTime,
          mealType: preview.mealType,
          sourceType: preview.sourceType,
          logId: preview.logId,
          summary: preview.summary
        )

        localScheduledOverrides[updatedPreview.id] = updatedPreview
        scheduledPreviews.append(updatedPreview)
        scheduledPreviews.sort { $0.normalizedTargetDate < $1.normalizedTargetDate }
        activeScheduledIds.insert(updatedPreview.id)
      }
    } else {
      if let placeholderIdentifier {
        removePlaceholderLog(withIdentifier: placeholderIdentifier)
      }
      scheduledResolvedLogIds.removeValue(forKey: preview.id)
      scheduledPlaceholderIds.removeValue(forKey: preview.id)
      if action == .cancel {
        activeScheduledIds.remove(preview.id)
      }
    }

    await repository.refresh(date: preview.targetDate, force: true)
    if Calendar.current.isDate(preview.targetDate, inSameDayAs: selectedDate),
       let snapshot = repository.snapshot(for: selectedDate) {
      applySnapshot(snapshot)
    }

  }

  func fetchNutritionGoals(forceRefresh: Bool = false) {
    fetchCalorieGoal()

    if let goals = goalsStore.cachedGoals {
        applyNutritionGoals(goals, persist: false)
    } else {
        applyFallbackNutritionGoals()
    }

    goalsStore.ensureGoalsAvailable(email: email, forceRefresh: forceRefresh)
  }

  func refreshExpenditureData(force: Bool = false, historyDays: Int = 30) {
    print("🔄 refreshExpenditureData called: force=\(force), historyDays=\(historyDays), email=\(email)")
    guard !email.isEmpty else {
      print("❌ refreshExpenditureData: No email, aborting")
      return
    }
    let now = Date()
    if !force, let lastExpenditureRefresh, now.timeIntervalSince(lastExpenditureRefresh) < expenditureRefreshInterval {
      print("⏸️ refreshExpenditureData: Skipping - last refresh was \(Int(now.timeIntervalSince(lastExpenditureRefresh)))s ago")
      return
    }
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: now)
    let daysInMonth = calendar.range(of: .day, in: .month, for: today)?.count ?? historyDays
    let fetchDays = max(historyDays, daysInMonth)
    print("✅ refreshExpenditureData: Starting API fetch for \(fetchDays) days")
    lastExpenditureRefresh = now
    isLoadingExpenditure = true
    expenditureErrorMessage = nil

    let offsetMinutes = TimeZone.current.secondsFromGMT() / 60

    NetworkManagerTwo.shared.fetchExpenditureSummary(userEmail: email, forceRecompute: force, timezoneOffsetMinutes: offsetMinutes) { [weak self] result in
      guard let self else { return }
      self.isLoadingExpenditure = false
      switch result {
      case .success(let payload):
        self.expenditureSnapshot = payload.summary
        self.expenditureState = payload.state
      case .failure(let error):
        self.expenditureErrorMessage = error.localizedDescription
      }
    }

    NetworkManagerTwo.shared.fetchExpenditureHistory(userEmail: email, days: fetchDays, timezoneOffsetMinutes: offsetMinutes) { [weak self] result in
      guard let self else { return }
      switch result {
      case .success(let response):
        print("🔍 API returned \(response.days.count) days of expenditure history (requested \(fetchDays))")
        for (index, day) in response.days.prefix(5).enumerated() {
          let formatter = DateFormatter()
          formatter.dateFormat = "MMM dd"
          let dateStr = day.dateValue.map { formatter.string(from: $0) } ?? "nil"
          print("  Day \(index + 1) [\(dateStr)]: intake=\(day.caloriesLogged ?? 0), tdee=\(day.tdeeDisplay ?? 0)")
        }
        self.expenditureHistory = response.days.sorted {
          ($0.dateValue ?? Date.distantPast) < ($1.dateValue ?? Date.distantPast)
        }
      case .failure(let error):
        self.expenditureErrorMessage = error.localizedDescription
      }
    }
  }

  func refreshHealthMetrics(force: Bool = false, targetDate: Date? = nil) {
    guard !email.isEmpty else { return }
    let now = Date()
    if !force, let lastHealthMetricsRefresh, now.timeIntervalSince(lastHealthMetricsRefresh) < healthMetricsRefreshInterval {
      return
    }
    lastHealthMetricsRefresh = now
    isLoadingHealthMetrics = true
    healthMetricsErrorMessage = nil

    let offsetMinutes = TimeZone.current.secondsFromGMT() / 60
    let requestedDate = targetDate ?? selectedDate
    NetworkManagerTwo.shared.fetchHealthMetrics(
      userEmail: email,
      timezoneOffsetMinutes: offsetMinutes,
      targetDate: requestedDate
    ) { [weak self] result in
      guard let self else { return }
      self.isLoadingHealthMetrics = false
      switch result {
      case .success(let snapshot):
        self.healthMetricsSnapshot = snapshot
        self.logHealthMetricsSnapshot(snapshot, requestedDate: requestedDate)
      case .failure(let error):
        self.healthMetricsErrorMessage = error.localizedDescription
      }
    }
  }

  func refreshConsistency(force: Bool = false, refreshWeight: Bool = true) {
    guard !email.isEmpty else { return }
    if !force, weightConsistency != nil, foodConsistency != nil { return }

    consistencyTask?.cancel()
    let currentEmail = email
    let cachedWeight = weightConsistency
    let cachedFood = foodConsistency
    let shouldComputeWeight = refreshWeight || weightConsistency == nil
    let shouldComputeFood = force || foodConsistency == nil

    consistencyTask = Task.detached(priority: .background) { [weak self] in
      let weightResult: HabitConsistencyData? = shouldComputeWeight
        ? await DayLogsViewModel.computeWeightConsistency(for: currentEmail)
        : cachedWeight
      let foodResult: HabitConsistencyData? = shouldComputeFood
        ? await DayLogsViewModel.computeFoodConsistency(for: currentEmail)
        : cachedFood

      await MainActor.run {
        guard let self else { return }
        if Task.isCancelled { return }
        if shouldComputeWeight {
          self.weightConsistency = weightResult
        }
        if shouldComputeFood {
          self.foodConsistency = foodResult
        }
      }
    }
  }

  private func logHealthMetricsSnapshot(_ snapshot: NetworkManagerTwo.HealthMetricsSnapshot, requestedDate: Date?) {
    var context = "payload_date=\(snapshot.date)"
    if let requestedDate {
      context += " | requested=\(metricsDebugFormatter.string(from: requestedDate))"
    }
    print("📈 OuraMetrics Snapshot: \(context)")

    logMetricValue("Readiness", value: snapshot.readiness)
    logMetricValue("Sleep", value: snapshot.sleep)
    logMetricValue("Activity", value: snapshot.activity)
    logMetricValue("Stress", value: snapshot.stress)

    if let confidence = snapshot.confidence, !confidence.isEmpty {
      print("   • confidence: \(confidence)")
    }
    if let isEmpty = snapshot.isEmpty {
      print("   • isEmpty: \(isEmpty)")
    }
    if let source = snapshot.scoreSource {
      print("   • scoreSource: \(source)")
    }
    if let sourceScores = snapshot.sourceScores, !sourceScores.isEmpty {
      print("   • source scores:")
      for key in sourceScores.keys.sorted() {
        if let value = sourceScores[key] {
          print("       - \(key): \(String(format: "%.2f", value))")
        }
      }
    }

    if let components = snapshot.components {
      logMetricComponent("Readiness", values: components.readiness)
      logMetricComponent("Sleep", values: components.sleep)
      logMetricComponent("Activity", values: components.activity)
      logMetricComponent("Stress", values: components.stress)
    } else {
      print("   • components: none returned")
    }

    if let raw = snapshot.rawMetrics {
      logRawMetrics(raw)
    }
  }

  private func logMetricValue(_ label: String, value: Double?) {
    guard let value else { return }
    print("   • \(label): \(String(format: "%.2f", value))")
  }

  private func logMetricComponent(_ label: String, values: [String: Double]?) {
    guard let values, !values.isEmpty else { return }
    print("   • \(label) components:")
    for key in values.keys.sorted() {
      if let value = values[key] {
        print("       - \(key): \(String(format: "%.2f", value))")
      }
    }
  }

  private func logRawMetrics(_ raw: NetworkManagerTwo.HealthMetricRawMetrics) {
    print("   • raw metrics:")
    logRawMetric("HRV", value: raw.hrv, suffix: "ms")
    logRawMetric("HRV (short term)", value: raw.hrvShortTerm, suffix: "ms")
    logRawMetric("HRV baseline", value: raw.hrvBaseline, suffix: "ms")
    logRawMetric("Resting HR", value: raw.restingHeartRate, suffix: "bpm")
    logRawMetric("Sleep hours", value: raw.sleepHours)
    logRawMetric("Sleep score", value: raw.sleepScore)
    logRawMetric("Steps", value: raw.steps)
    logRawMetric("Calories burned", value: raw.caloriesBurned)
    logRawMetric("Respiratory rate", value: raw.respiratoryRate)
    logRawMetric("Skin temperature", value: raw.skinTemperatureC)
    logRawMetric("Sleep latency", value: raw.sleepLatencyMinutes, suffix: "min")
    logRawMetric("Sleep midpoint", value: raw.sleepMidpointMinutes, suffix: "min")
    logRawMetric("Sleep need", value: raw.sleepNeedHours, suffix: "h")
    logRawMetric("Strain ratio", value: raw.strainRatio)
    logRawMetric("Total sleep", value: raw.totalSleepMinutes, suffix: "min")
    logRawMetric("In bed", value: raw.inBedMinutes, suffix: "min")
    logRawMetric("Sleep efficiency", value: raw.sleepEfficiency)
    if let sleepSource = raw.sleepSource {
      print("     • sleep source: \(sleepSource)")
    }
    if let fallbackDate = raw.fallbackSleepDate {
      print("     • fallback sleep date: \(fallbackDate)")
    }
    if let stages = raw.sleepStageMinutes {
      print("     • sleep stages:")
      logRawMetric("Deep", value: stages.deep, suffix: "min", indent: "       ")
      logRawMetric("REM", value: stages.rem, suffix: "min", indent: "       ")
      logRawMetric("Core", value: stages.core, suffix: "min", indent: "       ")
      logRawMetric("Awake", value: stages.awake, suffix: "min", indent: "       ")
    }
  }

  private func logRawMetric(_ label: String, value: Double?, suffix: String? = nil, indent: String = "     • ") {
    guard let value else { return }
    let formatted = String(format: "%.2f", value)
    if let suffix {
      print("\(indent)\(label): \(formatted) \(suffix)")
    } else {
      print("\(indent)\(label): \(formatted)")
    }
  }



func addPending(_ log: CombinedLog) {
  let key = Calendar.current.startOfDay(for: log.scheduledAt!)
    print("[DayLogsVM] addPending( id:\(log.id), dateKey:\(key) )")

  // If a server-confirmed workout arrives, remove any optimistic workout placeholders for the same day
  if log.type == .workout && log.isOptimistic == false {
    // Clean from pending cache for the same day
    if var arr = pendingByDate[key] {
      let before = arr.count
      arr.removeAll { $0.type == .workout && $0.isOptimistic }
      if arr.count != before { pendingByDate[key] = arr }
    }

    // Clean from visible logs for the same day
    logs.removeAll { item in
      guard item.type == .workout && item.isOptimistic else { return false }
      if let sched = item.scheduledAt { return Calendar.current.isDate(sched, inSameDayAs: key) }
      return false
    }
  }

  var arr = pendingByDate[key] ?? []

  // don't double-insert the same ID
  guard !arr.contains(where: { $0.id == log.id }) else { return }

  arr.insert(log, at: 0)
  pendingByDate[key] = arr

  if Calendar.current.isDate(log.scheduledAt!, inSameDayAs: selectedDate) {
    // again, guard against duplicates in the live `logs` array
    if !logs.contains(where: { $0.id == log.id }) {
      logs.insert(log, at: 0)
      
      // Re-sort logs to maintain chronological order (most recent first)
      logs.sort { log1, log2 in
        let date1 = log1.scheduledAt ?? Date.distantPast
        let date2 = log2.scheduledAt ?? Date.distantPast
        return date1 > date2  // Most recent first
      }
      
      print("[DayLogsVM] logs.inserted \(log.id), logs now = \(logs.map { $0.id })")
    }
  }
  
  // Trigger profile data refresh since logs changed
  triggerProfileDataRefresh(localOnly: true)
  
  // Update streak when any activity is logged
  StreakManager.shared.updateStreak(activityDate: log.scheduledAt ?? Date())
}

func replaceOptimisticLog(identifier: String, with resolvedLog: CombinedLog) {
  var resolved = resolvedLog
  resolved.isOptimistic = false

  // Remove the placeholder from any pending caches so it doesn't linger once confirmed
  let placeholderRemoved = removeOptimisticPlaceholder(identifier: identifier)

  // Update the visible logs if we're currently viewing this day
  var updatedLogs = logs
  if let index = updatedLogs.firstIndex(where: { $0.id == identifier }) {
    updatedLogs[index] = resolved
    logs = sortLogs(updatedLogs)
  } else if Calendar.current.isDate(resolved.scheduledAt ?? selectedDate, inSameDayAs: selectedDate) {
    updatedLogs.append(resolved)
    logs = sortLogs(updatedLogs)
  } else if !placeholderRemoved {
    // If the placeholder wasn't present anywhere, nothing else to update
    return
  }

  triggerProfileDataRefresh(localOnly: true)
}

func removeOptimisticLog(identifier: String) {
  let removedFromPending = removeOptimisticPlaceholder(identifier: identifier)
  let originalCount = logs.count
  logs.removeAll { $0.id == identifier }

  if removedFromPending || logs.count != originalCount {
    triggerProfileDataRefresh(localOnly: true)
  }
}

@discardableResult
private func removeOptimisticPlaceholder(identifier: String) -> Bool {
  var didRemove = false
  for key in Array(pendingByDate.keys) {
    var pending = pendingByDate[key] ?? []
    let originalCount = pending.count
    pending.removeAll { $0.id == identifier }
    if pending.isEmpty && originalCount > 0 {
      pendingByDate.removeValue(forKey: key)
      didRemove = true
    } else if pending.count != originalCount {
      pendingByDate[key] = pending
      didRemove = true
    }
  }
  return didRemove
}

private func sortLogs(_ logs: [CombinedLog]) -> [CombinedLog] {
  logs.sorted { first, second in
    let firstDate = first.scheduledAt ?? Date.distantPast
    let secondDate = second.scheduledAt ?? Date.distantPast
    return firstDate > secondDate
  }
}

func removeLog(_ log: CombinedLog) async {
    print("[DayLogsVM] removeLog( id:\(log.id), type:\(log.type) ) – optimistic remove + server sync")

    // Keep backups for rollback on failure
    let previousLogs = logs
    let previousPending = pendingByDate

    // 1) Optimistic local removal for immediate UI feedback
    logs.removeAll { $0.id == log.id }

    if let scheduledAt = log.scheduledAt {
        let key = Calendar.current.startOfDay(for: scheduledAt)
        if var pendingLogs = pendingByDate[key] {
            pendingLogs.removeAll { $0.id == log.id }
            pendingByDate[key] = pendingLogs
        }
    }

    print("[DayLogsVM] Optimistically removed log \(log.id); remaining = \(logs.map { $0.id })")
    triggerProfileDataRefresh(localOnly: true)

    // 2) Attempt server deletion
    do {
        try await deleteOnServer(log)
        print("[DayLogsVM] ✅ Server deletion succeeded for log \(log.id)")
        triggerProfileDataRefresh(localOnly: true)
    } catch {
        // 3) Rollback on failure and surface error to UI
        print("[DayLogsVM] ❌ Server deletion failed for log \(log.id): \(error.localizedDescription). Rolling back…")
        logs = previousLogs
        pendingByDate = previousPending
        self.error = error
        triggerProfileDataRefresh(localOnly: true)
    }
}

// Bridge deletion endpoints behind a single async function
private func deleteOnServer(_ log: CombinedLog) async throws {
    switch log.type {
    case .food:
        guard let foodLogId = log.foodLogId else {
            throw NSError(domain: "DayLogsViewModel", code: -1, userInfo: [NSLocalizedDescriptionKey: "Missing food log ID"])
        }
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            logNetwork.deleteLogItem(email: email, logId: foodLogId, logType: "food") { result in
                switch result {
                case .success:
                    continuation.resume()
                case .failure(let err):
                    continuation.resume(throwing: err)
                }
            }
        }

    case .meal:
        guard let mealLogId = log.mealLogId else {
            throw NSError(domain: "DayLogsViewModel", code: -1, userInfo: [NSLocalizedDescriptionKey: "Missing meal log ID"])
        }
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            logNetwork.deleteLogItem(email: email, logId: mealLogId, logType: "meal") { result in
                switch result {
                case .success:
                    continuation.resume()
                case .failure(let err):
                    continuation.resume(throwing: err)
                }
            }
        }

    case .recipe:
        guard let recipeLogId = log.recipeLogId else {
            throw NSError(domain: "DayLogsViewModel", code: -1, userInfo: [NSLocalizedDescriptionKey: "Missing recipe log ID"])
        }
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            logNetwork.deleteLogItem(email: email, logId: recipeLogId, logType: "recipe") { result in
                switch result {
                case .success:
                    continuation.resume()
                case .failure(let err):
                    continuation.resume(throwing: err)
                }
            }
        }

    case .activity:
        // HealthKit activities (UUID-style) cannot be deleted from server – ignore server sync
        guard let activityId = log.activityId else {
            throw NSError(domain: "DayLogsViewModel", code: -1, userInfo: [NSLocalizedDescriptionKey: "Missing activity ID"])
        }
        let isHealthKit = activityId.count > 10 && activityId.contains("-")
        if isHealthKit {
            // No server-side deletion for HealthKit entries; keep local removal
            print("[DayLogsVM] Skipping server deletion for HealthKit activity: \(activityId)")
            return
        }
        guard let aiActivityLogId = Int(activityId) else {
            throw NSError(domain: "DayLogsViewModel", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid AI activity ID"])
        }
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            NetworkManagerTwo.shared.deleteActivityLog(activityLogId: aiActivityLogId) { result in
                switch result {
                case .success:
                    continuation.resume()
                case .failure(let err):
                    continuation.resume(throwing: err)
                }
            }
        }

    case .workout:
        // Workouts are permanent records - do not allow deletion from dashboard
        print("[DayLogsVM] Workout deletion not implemented - completed workouts are permanent records")
        throw NSError(domain: "DayLogsViewModel", code: -1, userInfo: [NSLocalizedDescriptionKey: "Workout logs cannot be deleted"])
    }
}

func loadLogs(for date: Date, force: Bool = false) {
  let newKey = Calendar.current.startOfDay(for: date)
  let displayedKey = currentSnapshotDate ?? (logs.isEmpty ? nil : Calendar.current.startOfDay(for: selectedDate))

  // Clear the in-memory logs as soon as we target a different day so UI never shows stale data
  if displayedKey != newKey {
    logs = []

    if let displayedKey {
      pendingByDate.removeValue(forKey: displayedKey)
      print("[DayLogsVM] Cleared pending cache for date: \(displayedKey)")
    }

    currentSnapshotDate = nil
  }

  selectedDate = date

  // Clean up stale pending logs (older than 5 minutes)
  cleanupStalePendingLogs()

  // Always load fresh data when date changes to ensure correctness
  // TTL check removed to prevent race condition where selectedDate updates but logs don't
  isLoading = true
  error = nil

  Task { @MainActor [weak self] in
    guard let self else { return }
    await self.repository.refresh(date: date, force: force)
    let calendar = Calendar.current
    let requestedDay = calendar.startOfDay(for: date)
    let activeDay = calendar.startOfDay(for: self.selectedDate)
    // Ignore responses for stale date selections so fast switching can't overwrite the UI with old data
    guard requestedDay == activeDay else {
      print("[DayLogsVM] Skipping snapshot apply - selectedDate changed from \(requestedDay) to \(activeDay)")
      self.isLoading = false
      self.pendingNotificationReload = false
      return
    }
    if let snapshot = self.repository.snapshot(for: date) {
      self.applySnapshot(snapshot)
    } else {
      self.isLoading = false
      self.pendingNotificationReload = false
    }
  }
}

private func applySnapshot(_ snapshot: DayLogsSnapshot) {
  let key = Calendar.current.startOfDay(for: snapshot.date)
  currentSnapshotDate = key
  let serverLogs = snapshot.combined
  reconcilePlaceholders(with: serverLogs)
  let pending = pendingByDate[key] ?? []
  let dedupedPending = pending.filter { item in
    !serverLogs.contains(where: { $0.id == item.id })
  }
  pendingByDate[key] = dedupedPending

  let activityLogs = getActivityLogsFromHealth(for: snapshot.date)
  let combinedLogs = dedupedPending + serverLogs + activityLogs

  logs = combinedLogs.sorted { log1, log2 in
    let date1 = log1.scheduledAt ?? Date.distantPast
    let date2 = log2.scheduledAt ?? Date.distantPast
    return date1 > date2
  }

  let calendar = Calendar.current
  let sortedScheduled = snapshot.scheduled.sorted { lhs, rhs in
    if lhs.targetDate == rhs.targetDate {
      return (lhs.targetTime ?? "") < (rhs.targetTime ?? "")
    }
    return lhs.targetDate < rhs.targetDate
  }

  var serverIds = Set(sortedScheduled.map { $0.id })
  if !serverIds.isEmpty {
    skippedScheduledDates = skippedScheduledDates.filter { serverIds.contains($0.key) }
  }
  hiddenScheduledIds = hiddenScheduledIds.intersection(serverIds)

  // Drop local overrides that the server now owns
  for id in serverIds {
    localScheduledOverrides.removeValue(forKey: id)
  }

  var combinedScheduled: [ScheduledLogPreview] = []
  combinedScheduled.reserveCapacity(sortedScheduled.count + localScheduledOverrides.count)

  for preview in sortedScheduled where !hiddenScheduledIds.contains(preview.id) {
    if let skippedDate = skippedScheduledDates[preview.id] {
      if calendar.isDate(skippedDate, inSameDayAs: preview.normalizedTargetDate) {
        continue
      } else {
        skippedScheduledDates.removeValue(forKey: preview.id)
      }
    }
    combinedScheduled.append(preview)
  }

  for override in localScheduledOverrides.values where !hiddenScheduledIds.contains(override.id) {
    if let skippedDate = skippedScheduledDates[override.id] {
      if calendar.isDate(skippedDate, inSameDayAs: override.normalizedTargetDate) {
        continue
      } else {
        skippedScheduledDates.removeValue(forKey: override.id)
      }
    }
    combinedScheduled.append(override)
    serverIds.insert(override.id)
  }

  combinedScheduled.sort { lhs, rhs in
    if lhs.normalizedTargetDate == rhs.normalizedTargetDate {
      return (lhs.targetTime ?? "") < (rhs.targetTime ?? "")
    }
    return lhs.normalizedTargetDate < rhs.normalizedTargetDate
  }

  scheduledPreviews = combinedScheduled
  print("[DEBUG] scheduled previews for \(snapshot.date):", scheduledPreviews.map { ($0.id, $0.normalizedTargetDate) })

  #if DEBUG
  let debugPreviews = scheduledPreviews.map {
    "[Scheduled] id:\($0.id) targetDate:\($0.targetDate) normalized:\($0.normalizedTargetDate)"
  }.joined(separator: "\n")
  print("[DayLogsVM] Applied scheduled previews for \(snapshot.date):\n\(debugPreviews)")
  #endif

  let newIds = Set(scheduledPreviews.map { $0.id })
  activeScheduledIds = newIds

  lastLoadTimestamps[key] = Date()
  isLoading = false
  error = nil

  waterLogs = snapshot.water

  if let userData = snapshot.userData {
    height = userData.height_cm
    weight = userData.weight_kg

    if let encoded = try? JSONEncoder().encode(userData) {
      UserDefaults.standard.set(encoded, forKey: "userData")
    }
  }

  if let goals = snapshot.goals {
    applyNutritionGoals(goals, persist: true)
  }

  remainingCalories = max(0, calorieGoal - totalCalories)
  if pendingNotificationReload {
    pendingNotificationReload = false
    loadLogs(for: selectedDate, force: true)
  }
}




    private func recalculateTotals() {
      // Only count food/meal/recipe calories for intake (exclude activities and workouts)
      totalCalories = logs.reduce(0.0) { sum, log in
        // Activities and workouts burn calories, they don't contribute to calorie intake
        guard log.type != .activity && log.type != .workout else { return sum }
        return sum + log.displayCalories
      }

      totalProtein = logs.reduce(0.0) { sum, log in
        let p1 = log.food?.protein  ?? 0
        let p2 = log.meal?.protein  ?? 0
        let p3 = log.recipe?.protein ?? 0
        return sum + p1 + p2 + p3
      }

      totalCarbs = logs.reduce(0.0) { sum, log in
        let c1 = log.food?.carbs  ?? 0
        let c2 = log.meal?.carbs  ?? 0
        let c3 = log.recipe?.carbs ?? 0
        return sum + c1 + c2 + c3
      }

      totalFat = logs.reduce(0.0) { sum, log in
        let f1 = log.food?.fat  ?? 0
        let f2 = log.meal?.fat  ?? 0
        let f3 = log.recipe?.fat ?? 0
        return sum + f1 + f2 + f3
      }

      remainingCalories = max(0, calorieGoal - totalCalories)
    }

  // MARK: - Multi-day nutrition summaries

  func refreshWeeklyNutritionSummaries(endingAt date: Date = Date(), force: Bool = false) {
    Task { [weak self] in
      guard let self else { return }
      let summaries = await self.calculateNutritionSummaries(days: 7, endingAt: date, force: force)
      await MainActor.run {
        self.weeklyNutritionSummaries = summaries
      }
    }
  }

  private func calculateNutritionSummaries(days: Int, endingAt date: Date, force: Bool) async -> [DailyNutritionSummary] {
    guard days > 0 else { return [] }
    var summaries: [DailyNutritionSummary] = []
    let calendar = Calendar.current
    let normalizedEnd = calendar.startOfDay(for: date)

    for offset in stride(from: days - 1, through: 0, by: -1) {
      guard let target = calendar.date(byAdding: .day, value: -offset, to: normalizedEnd) else { continue }
      if !calendar.isDate(target, inSameDayAs: calendar.startOfDay(for: selectedDate)) {
        if force {
          await repository.refresh(date: target, force: true)
        } else if repository.snapshot(for: target) == nil {
          await repository.refresh(date: target, force: false)
        }
      }

      if let summary = nutritionSummary(for: target) {
        summaries.append(summary)
      }
    }

    return summaries
  }

  private func nutritionSummary(for date: Date) -> DailyNutritionSummary? {
    let calendar = Calendar.current
    let normalized = calendar.startOfDay(for: date)
    let selectedDay = calendar.startOfDay(for: selectedDate)

    if normalized == selectedDay {
      return DailyNutritionSummary(
        date: normalized,
        calories: totalCalories,
        protein: totalProtein,
        carbs: totalCarbs,
        fat: totalFat
      )
    }

    guard let snapshot = repository.snapshot(for: normalized) else { return nil }
    return DayLogsViewModel.aggregateNutritionTotals(from: snapshot.combined, date: normalized)
  }

  private static func aggregateNutritionTotals(from logs: [CombinedLog], date: Date) -> DailyNutritionSummary {
    var calories: Double = 0
    var protein: Double = 0
    var carbs: Double = 0
    var fat: Double = 0

    for log in logs {
      switch log.type {
      case .activity, .workout:
        break
      default:
        calories += log.displayCalories
      }

      protein += (log.food?.protein ?? 0)
      protein += (log.meal?.protein ?? 0)
      protein += (log.recipe?.protein ?? 0)

      carbs += (log.food?.carbs ?? 0)
      carbs += (log.meal?.carbs ?? 0)
      carbs += (log.recipe?.carbs ?? 0)

      fat += (log.food?.fat ?? 0)
      fat += (log.meal?.fat ?? 0)
      fat += (log.recipe?.fat ?? 0)
    }

    return DailyNutritionSummary(
      date: date,
      calories: calories,
      protein: protein,
      carbs: carbs,
      fat: fat
    )
  }

  private func energyBalancePoints(startingAt startDate: Date, days: Int) -> [EnergyBalancePoint] {
    guard days > 0 else { return [] }
    let calendar = Calendar.current
    let start = calendar.startOfDay(for: startDate)
    var map: [Date: NetworkManagerTwo.ExpenditureSnapshot] = [:]
    for snapshot in expenditureHistory {
      if let date = snapshot.dateValue {
        map[calendar.startOfDay(for: date)] = snapshot
      }
    }

    var points: [EnergyBalancePoint] = []
    for offset in 0..<days {
      guard let date = calendar.date(byAdding: .day, value: offset, to: start) else { continue }
      let day = calendar.startOfDay(for: date)
      let snapshot = map[day]
      let intake = snapshot?.caloriesLogged ?? 0
      let expenditure = snapshot?.tdeeDisplay ?? snapshot?.impliedExpenditure ?? snapshot?.tdeeCore ?? 0
      points.append(EnergyBalancePoint(date: day, intake: intake, expenditure: expenditure))
    }
    return points
  }

    // MARK: - Profile Data Refresh
    
    /// Trigger refresh of preloaded profile data whenever logs change
    private func triggerProfileDataRefresh(localOnly: Bool = true) {
        var info: [String: Any] = ["localOnly": localOnly, "source": "DayLogsViewModel"]
        NotificationCenter.default.post(
            name: NSNotification.Name("LogsChangedNotification"),
            object: nil,
            userInfo: info
        )
    }

    func updateLog(log: CombinedLog, servings: Double, date: Date, mealType: String, calories: Double? = nil, protein: Double? = nil, carbs: Double? = nil, fat: Double? = nil, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let foodLogId = log.foodLogId else {
    completion(.failure(NSError(domain: "DayLogsViewModel", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid log ID"])))
    return
  }

        // Call the repository to update the log
        logNetwork.updateLog(userEmail: email, logId: foodLogId, servings: servings, date: date, mealType: mealType, calories: calories, protein: protein, carbs: carbs, fat: fat) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let updatedFoodLog):
                    // Find the log in the local array
                    if let index = self.logs.firstIndex(where: { $0.id == log.id }) {
                        
                        let oldLogDate = self.logs[index].scheduledAt ?? Date()
                        let dateChanged = !Calendar.current.isDate(oldLogDate, inSameDayAs: date)
                        
                        if dateChanged {
                            // Log was moved to a different date
                            print("📅 Log moved from \(oldLogDate) to \(date)")
                            
                            // Remove from current day's logs
                            self.logs.remove(at: index)
                            
                            // Remove from current day's pending cache
                            let oldKey = Calendar.current.startOfDay(for: oldLogDate)
                            if var oldPending = self.pendingByDate[oldKey] {
                                oldPending.removeAll { $0.id == log.id }
                                if oldPending.isEmpty {
                                    self.pendingByDate.removeValue(forKey: oldKey)
                                } else {
                                    self.pendingByDate[oldKey] = oldPending
                                }
                            }
                            
                            // Add to new date's pending cache (so it shows up when user navigates there)
                            let newKey = Calendar.current.startOfDay(for: date)
                            var newPending = self.pendingByDate[newKey] ?? []
                            
                            // Create updated log for the new date
                            var updatedLog = log
                            updatedLog.food?.numberOfServings = updatedFoodLog.servings
                            updatedLog.mealType = updatedFoodLog.meal_type
                            updatedLog.scheduledAt = updatedFoodLog.logDate
                            updatedLog.message = "\(updatedFoodLog.food.displayName) – \(updatedFoodLog.meal_type)"
                            
                            // IMPORTANT: Use our edited calories value, not the backend's!
                            if let editedCalories = calories {
                                updatedLog.calories = editedCalories
                            } else {
                                updatedLog.calories = updatedFoodLog.calories
                            }
                            
                            // Update individual nutrient values if they were provided
                            if let calories = calories, let protein = protein, let carbs = carbs, let fat = fat, let food = updatedLog.food {
                                print("🔄 Updating food log (date change) with: calories=\(calories), protein=\(protein), carbs=\(carbs), fat=\(fat), servings=\(updatedFoodLog.servings)")
                                
                                // Avoid division by zero
                                let servingsCount = max(updatedFoodLog.servings, 0.1)
                                
                               updatedLog.food = LoggedFoodItem(
                                   foodLogId: food.foodLogId,
                                   fdcId: food.fdcId,
                                   displayName: food.displayName,
                                   calories: calories / servingsCount, // Store per-serving value
                                   servingSizeText: food.servingSizeText,
                                   numberOfServings: updatedFoodLog.servings,
                                   brandText: food.brandText,
                                   protein: protein / servingsCount,
                                   carbs: carbs / servingsCount,
                                   fat: fat / servingsCount,
                                   healthAnalysis: food.healthAnalysis,
                                    foodNutrients: food.foodNutrients,
                                    aiInsight: food.aiInsight,
                                    nutritionScore: food.nutritionScore
                               )
                                
                                print("✅ Updated food log locally (date change) with per-serving values: cal=\(calories / servingsCount), prot=\(protein / servingsCount), carbs=\(carbs / servingsCount), fat=\(fat / servingsCount)")
                            }
                            
                            // Don't add duplicate to pending
                            if !newPending.contains(where: { $0.id == updatedLog.id }) {
                                newPending.insert(updatedLog, at: 0)
                                self.pendingByDate[newKey] = newPending
                            }
                            
                            print("✅ Log removed from current day and added to target date's cache")
                            // DO NOT navigate automatically - let user stay on current date
                        } else {
                            // Same date – update in place **and** force Combine to emit
                            var updatedLog = self.logs[index]              // 1️⃣ copy the element (value-type struct)
                            updatedLog.food?.numberOfServings = updatedFoodLog.servings
                            updatedLog.mealType              = updatedFoodLog.meal_type
                            updatedLog.scheduledAt           = updatedFoodLog.logDate
                            updatedLog.message               = "\(updatedFoodLog.food.displayName) – \(updatedFoodLog.meal_type)"
                            
                            // IMPORTANT: Use our edited calories value, not the backend's!
                            if let editedCalories = calories {
                                updatedLog.calories = editedCalories
                            } else {
                                updatedLog.calories = updatedFoodLog.calories
                            }
                            
                            // Update individual nutrient values if they were provided
                            if let calories = calories, let protein = protein, let carbs = carbs, let fat = fat, let food = updatedLog.food {
                                print("🔄 Updating food log (same date) with: calories=\(calories), protein=\(protein), carbs=\(carbs), fat=\(fat), servings=\(updatedFoodLog.servings)")
                                
                                // Avoid division by zero
                                let servingsCount = max(updatedFoodLog.servings, 0.1)
                                
                               updatedLog.food = LoggedFoodItem(
                                   foodLogId: food.foodLogId,
                                   fdcId: food.fdcId,
                                   displayName: food.displayName,
                                   calories: calories / servingsCount, // Store per-serving value
                                   servingSizeText: food.servingSizeText,
                                   numberOfServings: updatedFoodLog.servings,
                                   brandText: food.brandText,
                                   protein: protein / servingsCount,
                                   carbs: carbs / servingsCount,
                                   fat: fat / servingsCount,
                                   healthAnalysis: food.healthAnalysis,
                                    foodNutrients: food.foodNutrients,
                                    aiInsight: food.aiInsight,
                                    nutritionScore: food.nutritionScore
                               )
                                
                                print("✅ Updated food log locally (same date) with per-serving values: cal=\(calories / servingsCount), prot=\(protein / servingsCount), carbs=\(carbs / servingsCount), fat=\(fat / servingsCount)")
                            }

                            // 2️⃣ Force SwiftUI to detect the change by replacing the entire array
                            var newLogs = self.logs
                            newLogs[index] = updatedLog
                            self.logs = newLogs
                            
                            print("📱 Force UI refresh for food log - replaced logs array")
                        }
                        
                        // Recalculate totals for current day
                        self.recalculateTotals()
                    }
                    
                    // Trigger profile data refresh since logs changed
                    self.triggerProfileDataRefresh(localOnly: true)
                    completion(.success(()))
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        }
    }

    func requestLogsReloadFromNotification() {
        if isLoading {
            pendingNotificationReload = true
        } else {
            pendingNotificationReload = false
            loadLogs(for: selectedDate, force: true)
        }
    }

    func updateMealLog(log: CombinedLog, servings: Double, date: Date, mealType: String, calories: Double? = nil, protein: Double? = nil, carbs: Double? = nil, fat: Double? = nil, completion: @escaping (Result<Void, Error>) -> Void) {
        print("🍽️ DayLogsViewModel: updateMealLog called")
        
        guard let mealLogId = log.mealLogId else {
            print("❌ DayLogsViewModel: No mealLogId found")
            completion(.failure(NSError(domain: "DayLogsViewModel", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid meal log ID"])))
            return
        }

        print("🔄 DayLogsViewModel: Calling logNetwork.updateMealLog with ID: \(mealLogId)")
        // Call the repository to update the meal log
        logNetwork.updateMealLog(userEmail: email, logId: mealLogId, servings: servings, date: date, mealType: mealType, calories: calories, protein: protein, carbs: carbs, fat: fat) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let updatedMealLog):
                    // Find the log in the local array
                    if let index = self.logs.firstIndex(where: { $0.id == log.id }) {
                        
                        let oldLogDate = self.logs[index].scheduledAt ?? Date()
                        let dateChanged = !Calendar.current.isDate(oldLogDate, inSameDayAs: date)
                        
                        if dateChanged {
                            // Log was moved to a different date
                            print("📅 Meal log moved from \(oldLogDate) to \(date)")
                            
                            // Remove from current day's logs
                            self.logs.remove(at: index)
                            
                            // Remove from current day's pending cache
                            let oldKey = Calendar.current.startOfDay(for: oldLogDate)
                            if var oldPending = self.pendingByDate[oldKey] {
                                oldPending.removeAll { $0.id == log.id }
                                if oldPending.isEmpty {
                                    self.pendingByDate.removeValue(forKey: oldKey)
                                } else {
                                    self.pendingByDate[oldKey] = oldPending
                                }
                            }
                            
                            // Add to new date's pending cache (so it shows up when user navigates there)
                            let newKey = Calendar.current.startOfDay(for: date)
                            var newPending = self.pendingByDate[newKey] ?? []
                            
                            // Create updated log for the new date
                            var updatedLog = log
                            if let existingMeal = updatedLog.meal {
                                // Update nutrient values if they were provided, otherwise keep original per-serving values
                                let servingsCount = max(updatedMealLog.servings_consumed, 0.1)
                                let perServingCalories = calories.map { $0 / servingsCount } ?? existingMeal.calories
                                let perServingProtein = protein.map { $0 / servingsCount } ?? existingMeal.protein
                                let perServingCarbs = carbs.map { $0 / servingsCount } ?? existingMeal.carbs
                                let perServingFat = fat.map { $0 / servingsCount } ?? existingMeal.fat
                                
                                if let calories = calories, let protein = protein, let carbs = carbs, let fat = fat {
                                    print("🔄 Updating meal log (date change) with: calories=\(calories), protein=\(protein), carbs=\(carbs), fat=\(fat), servings=\(servingsCount)")
                                    print("✅ Per-serving values: cal=\(perServingCalories), prot=\(perServingProtein ?? 0), carbs=\(perServingCarbs ?? 0), fat=\(perServingFat ?? 0)")
                                }
                                
                                updatedLog.meal = MealSummary(
                                    mealLogId: existingMeal.mealLogId,
                                    mealId: existingMeal.mealId,
                                    title: existingMeal.title,
                                    description: existingMeal.description,
                                    image: existingMeal.image,
                                    calories: perServingCalories,
                                    servings: updatedMealLog.servings_consumed,
                                    protein: perServingProtein,
                                    carbs: perServingCarbs,
                                    fat: perServingFat,
                                    scheduledAt: existingMeal.scheduledAt
                                )
                            }
                            
                            // IMPORTANT: Use our edited calories value, not the backend's!
                            if let editedCalories = calories {
                                updatedLog.calories = editedCalories
                            } else {
                                updatedLog.calories = updatedMealLog.calories
                            }
                            
                            updatedLog.mealType = updatedMealLog.meal_type
                            updatedLog.scheduledAt = ISO8601DateFormatter().date(from: updatedMealLog.date)
                            updatedLog.message = "\(updatedMealLog.meal.title) – \(updatedMealLog.meal_type)"
                            
                            // Don't add duplicate to pending
                            if !newPending.contains(where: { $0.id == updatedLog.id }) {
                                newPending.insert(updatedLog, at: 0)
                                self.pendingByDate[newKey] = newPending
                            }
                            
                            print("✅ Meal log removed from current day and added to target date's cache")
                            // DO NOT navigate automatically - let user stay on current date
                        } else {
                            // Same date – update in place **and** force Combine to emit
                            var updatedLog = self.logs[index]              // 1️⃣ copy the element (value-type struct)
                            if let existingMeal = updatedLog.meal {
                                // Update nutrient values if they were provided, otherwise keep original per-serving values
                                let servingsCount = max(updatedMealLog.servings_consumed, 0.1)
                                let perServingCalories = calories.map { $0 / servingsCount } ?? existingMeal.calories
                                let perServingProtein = protein.map { $0 / servingsCount } ?? existingMeal.protein
                                let perServingCarbs = carbs.map { $0 / servingsCount } ?? existingMeal.carbs
                                let perServingFat = fat.map { $0 / servingsCount } ?? existingMeal.fat
                                
                                if let calories = calories, let protein = protein, let carbs = carbs, let fat = fat {
                                    print("🔄 Updating meal log (same date) with: calories=\(calories), protein=\(protein), carbs=\(carbs), fat=\(fat), servings=\(servingsCount)")
                                    print("✅ Per-serving values: cal=\(perServingCalories), prot=\(perServingProtein ?? 0), carbs=\(perServingCarbs ?? 0), fat=\(perServingFat ?? 0)")
                                }
                                
                                updatedLog.meal = MealSummary(
                                    mealLogId: existingMeal.mealLogId,
                                    mealId: existingMeal.mealId,
                                    title: existingMeal.title,
                                    description: existingMeal.description,
                                    image: existingMeal.image,
                                    calories: perServingCalories,
                                    servings: updatedMealLog.servings_consumed,
                                    protein: perServingProtein,
                                    carbs: perServingCarbs,
                                    fat: perServingFat,
                                    scheduledAt: existingMeal.scheduledAt
                                )
                            }
                            
                            // IMPORTANT: Use our edited calories value, not the backend's!
                            if let editedCalories = calories {
                                updatedLog.calories = editedCalories
                            } else {
                                updatedLog.calories = updatedMealLog.calories
                            }
                            
                            updatedLog.mealType = updatedMealLog.meal_type
                            updatedLog.scheduledAt = ISO8601DateFormatter().date(from: updatedMealLog.date)
                            updatedLog.message = "\(updatedMealLog.meal.title) – \(updatedMealLog.meal_type)"

                            // 2️⃣ Force SwiftUI to detect the change by replacing the entire array
                            var newLogs = self.logs
                            newLogs[index] = updatedLog
                            self.logs = newLogs
                            
                            print("📱 Force UI refresh for meal log - replaced logs array")
                        }
                        
                        // Recalculate totals for current day
                        self.recalculateTotals()
                    }
                    
                    // Trigger profile data refresh since logs changed
                    self.triggerProfileDataRefresh(localOnly: true)
                    completion(.success(()))
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        }
    }

  // MARK: - Cache Management

  /// Clear the pending logs cache to prevent showing stale data
  private func clearPendingCache() {
      pendingByDate.removeAll()
      activeScheduledIds.removeAll()
      scheduledPlaceholderIds.removeAll()
      scheduledResolvedLogIds.removeAll()
      hiddenScheduledIds.removeAll()
      skippedScheduledDates.removeAll()
      localScheduledOverrides.removeAll()
      scheduledPreviews = []
      print("[DayLogsVM] Cleared pending cache")
  }

  /// Clean up stale pending logs older than 5 minutes to prevent accumulation
  /// NOTE: Optimistic logs (isOptimistic = true) are never cleaned up - they will be
  /// replaced when the server confirms or removed on failure
  private func cleanupStalePendingLogs() {
      let staleThreshold: TimeInterval = 5 * 60 // 5 minutes
      let now = Date()

      var keysToRemove: [Date] = []

      for (dateKey, logs) in pendingByDate {
          // Filter out logs older than 5 minutes, but keep optimistic logs
          // Optimistic logs will be replaced when server confirms or removed on failure
          let freshLogs = logs.filter { log in
              // Always keep optimistic logs - they'll be replaced when server confirms
              if log.isOptimistic {
                  return true
              }
              guard let scheduledAt = log.scheduledAt else { return false }
              return now.timeIntervalSince(scheduledAt) < staleThreshold
          }

          if freshLogs.isEmpty {
              keysToRemove.append(dateKey)
          } else if freshLogs.count != logs.count {
              pendingByDate[dateKey] = freshLogs
              print("[DayLogsVM] Cleaned up \(logs.count - freshLogs.count) stale pending logs for \(dateKey)")
          }
      }

      for key in keysToRemove {
      pendingByDate.removeValue(forKey: key)
      print("[DayLogsVM] Removed all stale pending logs for \(key)")
  }
}
  
  // MARK: - Activity Log Helpers
  
  private func getActivityLogsFromHealth(for date: Date) -> [CombinedLog] {
      // Get the shared HealthKitViewModel instance
      guard let healthViewModel = getHealthKitViewModel() else {
          print("[DayLogsVM] No HealthKitViewModel available")
          return []
      }
      
      let activities = healthViewModel.getActivityLogs(for: date)
      
      return activities.map { activity in
          CombinedLog(
              type: .activity,
              status: "success",
              calories: activity.totalEnergyBurned ?? 0,
              message: activity.displayName,
              scheduledAt: activity.startDate,
              activityId: activity.id,
              activity: activity,
              logDate: formatDateForLog(activity.startDate),
              dayOfWeek: formatDayOfWeek(activity.startDate)
          )
      }
  }
  
  private func getHealthKitViewModel() -> HealthKitViewModel? {
      // Try to get the HealthKitViewModel from the app's environment
      // This is a simplified approach - in a real app, you'd inject this dependency
      return healthViewModel ?? HealthKitViewModel.shared
  }
  
  private func formatDateForLog(_ date: Date) -> String {
      let formatter = DateFormatter()
      formatter.dateFormat = "yyyy-MM-dd"
      return formatter.string(from: date)
  }
  
  private func formatDayOfWeek(_ date: Date) -> String {
      let formatter = DateFormatter()
      formatter.dateFormat = "EEEE"
      return formatter.string(from: date)
  }

  // MARK: - Scheduled Log Helpers

  func removeScheduledPreview(_ preview: ScheduledLogPreview, recordSkip: Bool = true) {
    let id = preview.id
    if let index = scheduledPreviews.firstIndex(where: { $0.id == id }) {
      scheduledPreviews.remove(at: index)
    }
    activeScheduledIds.remove(id)
    hiddenScheduledIds.insert(id)
    if recordSkip {
      skippedScheduledDates[id] = preview.normalizedTargetDate
    } else {
      skippedScheduledDates.removeValue(forKey: id)
    }
    localScheduledOverrides.removeValue(forKey: id)
  }

  func upsertScheduledPreview(from response: ScheduleMealResponse, sourceLog: CombinedLog) {
    let mealType = response.mealType ?? sourceLog.mealType ?? sourceLog.mealTime

    let summary = ScheduledLogSummary(
      title: summaryTitle(for: sourceLog),
      calories: summaryCalories(for: sourceLog),
      servings: summaryServings(for: sourceLog),
      mealType: mealType,
      image: summaryImage(for: sourceLog),
      protein: summaryProtein(for: sourceLog),
      carbs: summaryCarbs(for: sourceLog),
      fat: summaryFat(for: sourceLog),
      aiInsight: sourceLog.food?.aiInsight,
      nutritionScore: sourceLog.food?.nutritionScore
    )

    let preview = ScheduledLogPreview(
      id: response.id,
      scheduleType: response.scheduleType,
      targetDate: response.targetDate,
      targetTime: response.targetTime,
      mealType: mealType,
      sourceType: response.sourceType,
      logId: response.logId,
      summary: summary
    )

    localScheduledOverrides[preview.id] = preview
    scheduledPreviews.removeAll { $0.id == preview.id }
    scheduledPreviews.append(preview)
    scheduledPreviews.sort { lhs, rhs in
      if lhs.normalizedTargetDate == rhs.normalizedTargetDate {
        return (lhs.targetTime ?? "") < (rhs.targetTime ?? "")
      }
      return lhs.normalizedTargetDate < rhs.normalizedTargetDate
    }

    activeScheduledIds.insert(preview.id)
    hiddenScheduledIds.remove(preview.id)
    skippedScheduledDates.removeValue(forKey: preview.id)
  }

  func restoreScheduledPreview(_ preview: ScheduledLogPreview) {
    guard scheduledPreviews.contains(where: { $0.id == preview.id }) == false else { return }
    hiddenScheduledIds.remove(preview.id)
    skippedScheduledDates.removeValue(forKey: preview.id)
    localScheduledOverrides.removeValue(forKey: preview.id)
    scheduledPreviews.append(preview)
    scheduledPreviews.sort { lhs, rhs in
      if lhs.targetDate == rhs.targetDate {
        return (lhs.targetTime ?? "") < (rhs.targetTime ?? "")
      }
      return lhs.targetDate < rhs.targetDate
    }
    activeScheduledIds.insert(preview.id)
  }

  @discardableResult
  func addOptimisticScheduledLog(from preview: ScheduledLogPreview) -> String? {
    let scheduledAt = resolvedScheduledDate(for: preview)
    let logDate = formatDateForLog(scheduledAt)
    let dayName = formatDayOfWeek(scheduledAt)
    let mealType = preview.displayMealType
    let calories = preview.summary.calories ?? 0
    let servings = max(preview.summary.servings ?? 1, 1)
    let message = "\(preview.summary.title) – \(mealType)"
    let placeholderId = -preview.id

    let combined: CombinedLog

    if preview.sourceType.lowercased() == "food" {
      let loggedFood = LoggedFoodItem(
        foodLogId: placeholderId,
        fdcId: preview.logId,
        displayName: preview.summary.title,
        calories: calories,
        servingSizeText: servings == 1 ? "1 serving" : "\(servings) servings",
        numberOfServings: servings,
        brandText: nil,
        protein: preview.summary.protein,
        carbs: preview.summary.carbs,
        fat: preview.summary.fat,
        healthAnalysis: nil,
        foodNutrients: nil,
        aiInsight: preview.summary.aiInsight,
        nutritionScore: preview.summary.nutritionScore
      )

      combined = CombinedLog(
        type: .food,
        status: "pending",
        calories: calories,
        message: message,
        foodLogId: placeholderId,
        food: loggedFood,
        mealType: mealType,
        mealLogId: nil,
        meal: nil,
        mealTime: mealType,
        scheduledAt: scheduledAt,
        recipeLogId: nil,
        recipe: nil,
        servingsConsumed: nil,
        activityId: nil,
        activity: nil,
        logDate: logDate,
        dayOfWeek: dayName,
        isOptimistic: true
      )
    } else {
      let mealSummary = MealSummary(
        mealLogId: placeholderId,
        mealId: preview.logId,
        title: preview.summary.title,
        description: nil,
        image: preview.summary.image,
        calories: calories,
        servings: servings,
        protein: preview.summary.protein,
        carbs: preview.summary.carbs,
        fat: preview.summary.fat,
        scheduledAt: scheduledAt
      )

      combined = CombinedLog(
        type: .meal,
        status: "pending",
        calories: calories,
        message: message,
        foodLogId: nil,
        food: nil,
        mealType: mealType,
        mealLogId: placeholderId,
        meal: mealSummary,
        mealTime: mealType,
        scheduledAt: scheduledAt,
        recipeLogId: nil,
        recipe: nil,
        servingsConsumed: nil,
        activityId: nil,
        activity: nil,
        logDate: logDate,
        dayOfWeek: dayName,
        isOptimistic: true
      )
    }

    addPending(combined)
    scheduledPlaceholderIds[preview.id] = combined.id
    return combined.id
  }

  func removePlaceholderLog(withIdentifier identifier: String) {
    var scheduledIdsToRemove: [Int] = []
    for (scheduledId, placeholderId) in scheduledPlaceholderIds where placeholderId == identifier {
      scheduledIdsToRemove.append(scheduledId)
    }

    for scheduledId in scheduledIdsToRemove {
      scheduledPlaceholderIds.removeValue(forKey: scheduledId)
      scheduledResolvedLogIds.removeValue(forKey: scheduledId)
    }

    var keysToClear: [Date] = []
    for key in Array(pendingByDate.keys) {
      var pending = pendingByDate[key] ?? []
      let originalCount = pending.count
      pending.removeAll { $0.id == identifier }
      if pending.isEmpty && originalCount > 0 {
        keysToClear.append(key)
      } else if pending.count != originalCount {
        pendingByDate[key] = pending
      }
    }

    for key in keysToClear {
      pendingByDate.removeValue(forKey: key)
    }

    if logs.contains(where: { $0.id == identifier }) {
      logs.removeAll { $0.id == identifier }
    }

    triggerProfileDataRefresh(localOnly: true)
  }

  private func markPlaceholderSettled(identifier: String) {
    var updatedLogs = logs
    if let index = updatedLogs.firstIndex(where: { $0.id == identifier }) {
      updatedLogs[index].isOptimistic = false
      logs = updatedLogs
    }

  for key in Array(pendingByDate.keys) {
    var pending = pendingByDate[key] ?? []
    if let index = pending.firstIndex(where: { $0.id == identifier }) {
      pending[index].isOptimistic = false
      pendingByDate[key] = pending
    }
  }
  triggerProfileDataRefresh(localOnly: true)
}

  private func reconcilePlaceholders(with serverLogs: [CombinedLog]) {
    guard scheduledPlaceholderIds.isEmpty == false else { return }

    let serverIds = Set(serverLogs.map(\.id))
    var placeholderIds: Set<String> = []
    var scheduledIdsToClear: [Int] = []

    for (scheduledId, placeholderId) in scheduledPlaceholderIds {
      guard let resolvedId = scheduledResolvedLogIds[scheduledId] else { continue }
      if serverIds.contains(resolvedId) {
        placeholderIds.insert(placeholderId)
        scheduledIdsToClear.append(scheduledId)
      }
    }

    guard placeholderIds.isEmpty == false else { return }

    for key in Array(pendingByDate.keys) {
      var pending = pendingByDate[key] ?? []
      let originalCount = pending.count
      pending.removeAll { placeholderIds.contains($0.id) }
      if pending.isEmpty && originalCount > 0 {
        pendingByDate.removeValue(forKey: key)
      } else if pending.count != originalCount {
        pendingByDate[key] = pending
      }
    }

    for scheduledId in scheduledIdsToClear {
      scheduledPlaceholderIds.removeValue(forKey: scheduledId)
      scheduledResolvedLogIds.removeValue(forKey: scheduledId)
    }
  }

  private func resolvedScheduledDate(for preview: ScheduledLogPreview) -> Date {
    preview.normalizedTargetDate
  }

  private func combinedIdentifier(for logType: String, logId: Int) -> String {
  switch logType.lowercased() {
  case "food":
    return "food_\(logId)"
  case "meal":
    return "meal_\(logId)"
  case "recipe":
    return "recipe_\(logId)"
  case "activity":
    return "activity_\(logId)"
  case "workout":
    return "workout_\(logId)"
  default:
    return "\(logType.lowercased())_\(logId)"
  }
}

  private func summaryTitle(for log: CombinedLog) -> String {
  switch log.type {
  case .food:
    return log.food?.displayName ?? log.message
  case .meal:
    return log.meal?.title ?? log.message
  case .recipe:
    return log.recipe?.title ?? log.message
  case .activity:
    return log.message
  case .workout:
    return log.workout?.title ?? log.message
  }
}

private func summaryCalories(for log: CombinedLog) -> Double? {
  switch log.type {
  case .food, .meal, .recipe:
    return log.displayCalories
  case .activity:
    return nil
  case .workout:
    return nil
  }
}

private func summaryServings(for log: CombinedLog) -> Double? {
  switch log.type {
    case .food:
      return log.food?.numberOfServings
    case .meal:
      return log.meal?.servings
  case .recipe:
    if let servings = log.recipe?.servings {
      return Double(servings)
    }
    return nil
  case .activity:
    return nil
  case .workout:
    return nil
  }
}

private func summaryProtein(for log: CombinedLog) -> Double? {
  switch log.type {
    case .food:
      return log.food?.protein
    case .meal:
      return log.meal?.protein
  case .recipe:
    return log.recipe?.protein
  case .activity:
    return nil
  case .workout:
    return nil
  }
}

private func summaryCarbs(for log: CombinedLog) -> Double? {
  switch log.type {
    case .food:
      return log.food?.carbs
    case .meal:
      return log.meal?.carbs
  case .recipe:
    return log.recipe?.carbs
  case .activity:
    return nil
  case .workout:
    return nil
  }
}

private func summaryFat(for log: CombinedLog) -> Double? {
  switch log.type {
    case .food:
      return log.food?.fat
    case .meal:
      return log.meal?.fat
  case .recipe:
    return log.recipe?.fat
  case .activity:
    return nil
  case .workout:
    return nil
  }
}

private func summaryImage(for log: CombinedLog) -> String? {
  switch log.type {
  case .food:
    return nil
  case .meal:
    return log.meal?.image
  case .recipe:
    return log.recipe?.image
  case .activity:
    return nil
  case .workout:
    return nil
  }
}
}

// MARK: - Habit Consistency Helpers

private extension DayLogsViewModel {
  static let consistencyWindowDays = 30
  static let weightLogFetchLimit = 200

  static let iso8601WithFractionalSeconds: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter
  }()

  static let iso8601BasicFormatter: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]
    return formatter
  }()

  static func computeFoodConsistency(for email: String) async -> HabitConsistencyData? {
    guard !email.isEmpty else { return nil }
    let counts = await fetchDailyLogCounts(days: consistencyWindowDays) { log in
      switch log.type {
      case .food, .meal, .recipe:
        return true
      case .activity, .workout:
        return false
      }
    }
    return buildConsistencyData(title: "Food Logging", counts: counts, days: consistencyWindowDays)
  }

  static func computeWeightConsistency(for email: String) async -> HabitConsistencyData? {
    guard !email.isEmpty else { return nil }
    let counts = await fetchWeightLogCounts(email: email, days: consistencyWindowDays)
    return buildConsistencyData(title: "Weigh-In", counts: counts, days: consistencyWindowDays)
  }

  static func fetchDailyLogCounts(
    days: Int,
    filter: @escaping (CombinedLog) -> Bool
  ) async -> [Date: Int] {
    var counts: [Date: Int] = [:]
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: Date())

    for offset in 0..<days {
      if Task.isCancelled { break }
      guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else { continue }
      let key = calendar.startOfDay(for: date)

      var snapshot: DayLogsSnapshot? = await MainActor.run {
        DayLogsRepository.shared.snapshot(for: key)
      }

      if snapshot == nil {
        await DayLogsRepository.shared.refresh(date: key, force: false)
        snapshot = await MainActor.run {
          DayLogsRepository.shared.snapshot(for: key)
        }
      }

      let filteredCount = snapshot?.combined.filter(filter).count ?? 0
      counts[key] = filteredCount
    }

    return counts
  }

  static func fetchWeightLogCounts(email: String, days: Int) async -> [Date: Int] {
    let logs = await fetchWeightLogs(email: email, limit: weightLogFetchLimit)
    guard !logs.isEmpty else { return [:] }

    let calendar = Calendar.current
    let today = calendar.startOfDay(for: Date())
    guard let startDate = calendar.date(byAdding: .day, value: -(days - 1), to: today) else {
      return [:]
    }

    var counts: [Date: Int] = [:]
    for log in logs {
      if Task.isCancelled { break }
      guard let parsedDate = parseWeightDate(log.dateLogged) else { continue }
      let normalized = calendar.startOfDay(for: parsedDate)
      guard normalized >= startDate, normalized <= today else { continue }
      counts[normalized, default: 0] += 1
    }

    return counts
  }

  static func fetchWeightLogs(email: String, limit: Int) async -> [WeightLogResponse] {
    await withCheckedContinuation { continuation in
      NetworkManagerTwo.shared.fetchWeightLogs(userEmail: email, limit: limit, offset: 0) { result in
        switch result {
        case .success(let response):
          continuation.resume(returning: response.logs)
        case .failure:
          continuation.resume(returning: [])
        }
      }
    }
  }

  static func parseWeightDate(_ raw: String) -> Date? {
    if let date = iso8601WithFractionalSeconds.date(from: raw) {
      return date
    }
    return iso8601BasicFormatter.date(from: raw)
  }

  static func buildConsistencyData(
    title: String,
    counts: [Date: Int],
    days: Int
  ) -> HabitConsistencyData {
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: Date())
    guard let startDate = calendar.date(byAdding: .day, value: -(days - 1), to: today) else {
      return HabitConsistencyData(
        title: title,
        weeklyCompleted: 0,
        weeklyTotal: 0,
        gridLevels: Array(repeating: 0, count: days)
      )
    }

    var levels: [Int] = []
    for offset in 0..<days {
      guard let date = calendar.date(byAdding: .day, value: offset, to: startDate) else { continue }
      let normalized = calendar.startOfDay(for: date)
      let count = counts[normalized] ?? 0
      levels.append(intensity(for: count))
    }

    if levels.count < days {
      levels.append(contentsOf: Array(repeating: 0, count: days - levels.count))
    }

    var weeklyCompleted = 0
    var weeklyTotal = 0
    if let interval = calendar.dateInterval(of: .weekOfYear, for: today) {
      var cursor = interval.start
      let weekEnd = min(
        today,
        calendar.date(byAdding: .day, value: 6, to: interval.start) ?? today
      )

      while cursor <= weekEnd {
        weeklyTotal += 1
        if (counts[cursor] ?? 0) > 0 {
          weeklyCompleted += 1
        }

        guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
        cursor = next
      }
    }

    return HabitConsistencyData(
      title: title,
      weeklyCompleted: weeklyCompleted,
      weeklyTotal: weeklyTotal,
      gridLevels: levels
    )
  }

  static func intensity(for count: Int) -> Int {
    guard count > 0 else { return 0 }
    switch count {
    case 1:
      return 4
    case 2:
      return 3
    case 3:
      return 2
    default:
      return 1
    }
  }
}
