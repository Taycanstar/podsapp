import SwiftUI
import SwiftData
import UIKit

struct WorkoutLogDetailView: View {
    private let log: CombinedLog

    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel: WorkoutLogDetailViewModel

    init(log: CombinedLog) {
        self.log = log
        _viewModel = StateObject(wrappedValue: WorkoutLogDetailViewModel(log: log))
    }

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.detail == nil {
                VStack(spacing: 16) {
                    ProgressView()
                    Text("Loading workout…")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color("primarybg").ignoresSafeArea())
            } else {
                detailContent
            }
        }
        .navigationTitle("Workout Details")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color("primarybg").ignoresSafeArea())
        .task {
            await viewModel.load(using: modelContext)
        }
    }

    private var detailContent: some View {
        let display = viewModel.detail ?? WorkoutLogDetailDisplay.makeFallback(from: log, units: viewModel.unitsSystem)

        return ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                headerSection(for: display)

                if let error = viewModel.errorMessage {
                    infoCard(
                        title: "Unable to load all details",
                        message: error
                    )
                } else if log.isOptimistic {
                    infoCard(
                        title: "Sync in progress",
                        message: "This workout is still syncing. Detailed sets will appear once sync completes."
                    )
                }

                if let notesText = display.trimmedNotes {
                    notesSection(text: notesText)
                }

                if !display.exercises.isEmpty {
                    exerciseSection(for: display)
                } else if display.isHealthKitImport {
                    infoCard(
                        title: "Imported Workout",
                        message: "This workout was imported from HealthKit. Detailed exercise breakdown is not available."
                    )
                } else if viewModel.isLoading {
                    ProgressView()
                        .padding(.top, 12)
                } else {
                    infoCard(
                        title: "No exercise data",
                        message: "We didn’t receive an exercise breakdown for this workout."
                    )
                }
            }
            .padding(.top, 20)
            .padding(.bottom, 32)
            .padding(.horizontal, 16)
        }
        .safeAreaPadding(.bottom, 88)
        .background(Color("primarybg"))
        .refreshable {
            await viewModel.reload(using: modelContext)
        }
    }

    @ViewBuilder
    private func headerSection(for detail: WorkoutLogDetailDisplay) -> some View {
        VStack(spacing: 16) {
            VStack(spacing: 4) {
                Text(detail.title)
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)

                if let dateString = detail.completedDateString {
                    Text(dateString)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                Text(detail.exerciseSummaryString)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 16) {
                StatCard(title: "Duration", value: detail.durationString, valueColor: Color("pinkRed"))
                StatCard(title: "Volume", value: detail.volumeString, valueColor: .cyan)
                StatCard(title: "Calories", value: detail.caloriesString, valueColor: Color("brightOrange"))
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color("altcard"))
        )
    }

    private func notesSection(text: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Notes")
                .font(.headline)
            Text(text)
                .font(.body)
                .foregroundStyle(.primary)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color("altcard"))
        )
    }

    private func exerciseSection(for detail: WorkoutLogDetailDisplay) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Exercises")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundStyle(.primary)

            VStack(spacing: 16) {
                ForEach(detail.exercises) { exercise in
                    WorkoutLogExerciseRow(
                        exercise: exercise,
                        unitsSymbol: detail.unitsSystem.weightSymbol,
                        onDelete: exercise.instanceId != nil ? { target in
                            await viewModel.deleteExercise(exercise: target, context: modelContext)
                        } : nil
                    )
                }
            }
        }
    }

    private func infoCard(title: String, message: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.headline)
            Text(message)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color("altcard"))
        )
    }
}

private struct StatCard: View {
    let title: String
    let value: String
    let valueColor: Color

    var body: some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.bold())
                .foregroundStyle(valueColor)
                .multilineTextAlignment(.center)
                .fontDesign(.rounded)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color("altcard"))
        )
    }
}

private struct WorkoutLogExerciseRow: View {
    let exercise: WorkoutLogDetailDisplay.Exercise
    let unitsSymbol: String
    let onDelete: ((WorkoutLogDetailDisplay.Exercise) async -> Result<String, Error>)?

    @State private var showHistory = false
    @State private var alertMessage: String?
    @State private var isShowingAlert = false
    @State private var historyPayload: TodayWorkoutExercise?
    @State private var isDeleting = false

    init(
        exercise: WorkoutLogDetailDisplay.Exercise,
        unitsSymbol: String,
        onDelete: ((WorkoutLogDetailDisplay.Exercise) async -> Result<String, Error>)? = nil
    ) {
        self.exercise = exercise
        self.unitsSymbol = unitsSymbol
        self.onDelete = onDelete
        _historyPayload = State(initialValue: exercise.historyExercise)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            thumbnail

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top) {
                    Text(exercise.name)
                        .font(.headline)

                    Spacer(minLength: 12)

                    optionsMenu
                }

                if let notes = exercise.trimmedNotes {
                    Text(notes)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if exercise.setDisplays.isEmpty {
                    Text("No sets logged")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(exercise.setDisplays.sorted(by: { $0.summary.index < $1.summary.index })) { set in
                            VStack(alignment: .leading, spacing: 4) {
                                if let line = setLine(for: set) {
                                    Text(line)
                                        .font(.subheadline)
                                        .foregroundStyle(.primary)
                                }

                                if let note = set.note {
                                    Text(note)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color("altbg"))
        )
        .sheet(isPresented: $showHistory) {
            if let payload = historyPayload {
                NavigationStack {
                    ExerciseHistory(exercise: payload)
                }
            }
        }
        .alert("Workout detail", isPresented: $isShowingAlert, actions: {
            Button("OK", role: .cancel) { }
        }, message: {
            Text(alertMessage ?? "")
        })
        .onChange(of: exercise.historyExercise) { newValue in
            historyPayload = newValue
        }
    }

    private var thumbnail: some View {
        let identifier = exercise.exerciseData?.id ?? exercise.exerciseId
        let imageName = identifier.map { String(format: "%04d", $0) }

        return Group {
            if let imageName,
               let image = UIImage(named: imageName) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemGray5))
                    Image(systemName: "figure.strengthtraining.traditional")
                        .font(.system(size: 22))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(width: 60, height: 60)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var optionsMenu: some View {
        Menu {
            Button("Exercise History") {
                alertMessage = nil
                isShowingAlert = false
                guard let payload = exercise.historyExercise else {
                    alertMessage = "Exercise history is unavailable for this entry."
                    isShowingAlert = true
                    return
                }
                historyPayload = payload
                showHistory = true
            }

            if let exerciseId = exercise.exerciseId {
                let userProfile = UserProfileService.shared
                let isAvoided = userProfile.isExerciseAvoided(exerciseId)

                Button("Recommend more often") {
                    userProfile.setExercisePreferenceMoreOften(exerciseId: exerciseId)
                    alertMessage = "We'll recommend \(exercise.name) more frequently."
                    isShowingAlert = true
                }

                Button("Recommend less often") {
                    userProfile.setExercisePreferenceLessOften(exerciseId: exerciseId)
                    alertMessage = "We'll recommend \(exercise.name) less often."
                    isShowingAlert = true
                }

                if isAvoided {
                    Button("Allow again") {
                        userProfile.removeFromAvoided(exerciseId)
                        alertMessage = "\(exercise.name) will be recommended again."
                        isShowingAlert = true
                    }
                } else {
                    Button("Don't recommend again", role: .destructive) {
                        userProfile.addToAvoided(exerciseId)
                        alertMessage = "\(exercise.name) won't be recommended again."
                        isShowingAlert = true
                    }
                }
            } else {
                Button("Recommend more often") {
                    alertMessage = "Exercise metadata unavailable."
                    isShowingAlert = true
                }
                Button("Recommend less often") {
                    alertMessage = "Exercise metadata unavailable."
                    isShowingAlert = true
                }
                Button("Don't recommend again", role: .destructive) {
                    alertMessage = "Exercise metadata unavailable."
                    isShowingAlert = true
                }
            }

            if let onDelete {
                Button(role: .destructive) {
                    guard !isDeleting else { return }
                    isDeleting = true
                    Task {
                        let result = await onDelete(exercise)
                        await MainActor.run {
                            switch result {
                            case .success:
                                alertMessage = nil
                                isShowingAlert = false
                                UINotificationFeedbackGenerator().notificationOccurred(.success)
                            case .failure(let error):
                                alertMessage = error.localizedDescription
                                isShowingAlert = true
                                UINotificationFeedbackGenerator().notificationOccurred(.error)
                            }
                            isDeleting = false
                        }
                    }
                } label: {
                    Text(isDeleting ? "Deleting…" : "Delete from workout")
                }
            } else {
                Button("Delete from workout", role: .destructive) {
                    alertMessage = "Completed workouts cannot be edited from this view."
                    isShowingAlert = true
                }
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 24, height: 24)
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
    }

    private func setLine(for set: WorkoutLogDetailDisplay.Exercise.SetDisplay) -> String? {
        let summary = set.summary
        let repsValue = summary.reps.map { Int(round($0)) }

        switch summary.trackingType {
        case .repsWeight:
            guard let reps = repsValue, reps > 0 else { return nil }
            if let weight = summary.weight, weight > 0 {
                return "\(reps) reps x \(formattedWeight(weight)) \(unitsSymbol)"
            }
            return "\(reps) reps"
        case .repsOnly:
            guard let reps = repsValue, reps > 0 else { return nil }
            return "\(reps) reps"
        case .timeOnly, .holdTime:
            guard let duration = summary.duration, duration > 0 else { return nil }
            return clockDurationString(duration)
        case .timeDistance:
            var components: [String] = []
            if let duration = summary.duration, duration > 0 {
                components.append(clockDurationString(duration))
            }
            if let distance = summary.distance, distance > 0 {
                let formatter = NumberFormatter()
                formatter.numberStyle = .decimal
                formatter.maximumFractionDigits = 2
                var value = formatter.string(from: NSNumber(value: distance)) ?? "\(distance)"
                if let unit = set.distanceUnit {
                    value += " \(unit.symbol)"
                }
                components.append(value)
            }
            return components.isEmpty ? nil : components.joined(separator: " · ")
        case .rounds:
            if let reps = repsValue, reps > 0 {
                return "\(reps) rounds"
            }
            return nil
        }
    }

    private func formattedWeight(_ weight: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        let usesDecimal = unitsSymbol == "kg" && weight.truncatingRemainder(dividingBy: 1) != 0
        formatter.maximumFractionDigits = usesDecimal ? 1 : 0
        return formatter.string(from: NSNumber(value: weight)) ?? String(format: "%.0f", weight)
    }

    private func clockDurationString(_ duration: TimeInterval) -> String {
        guard duration > 0 else { return "0:00" }
        let totalSeconds = Int(duration.rounded())
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }
}

@MainActor
final class WorkoutLogDetailViewModel: ObservableObject {
    @Published private(set) var detail: WorkoutLogDetailDisplay?
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    let log: CombinedLog

    private let workoutDataManager = WorkoutDataManager.shared
    private let networkManager = NetworkManagerTwo.shared

    private(set) var unitsSystem: UnitsSystem

    init(log: CombinedLog) {
        self.log = log
        self.unitsSystem = WorkoutLogDetailViewModel.resolveUnitsSystem()
    }

    func load(using context: ModelContext) async {
        await loadDetail(using: context, force: false)
    }

    func reload(using context: ModelContext) async {
        await loadDetail(using: context, force: true)
    }

    func deleteExercise(exercise: WorkoutLogDetailDisplay.Exercise, context: ModelContext) async -> Result<String, Error> {
        guard let exerciseInstanceId = exercise.instanceId else {
            return .failure(DeleteError.missingExerciseIdentifier)
        }

        guard let workoutId = resolveWorkoutId() else {
            return .failure(DetailError.missingWorkoutIdentifier)
        }

        guard let userEmail = WorkoutLogDetailViewModel.resolveUserEmail() else {
            return .failure(DetailError.missingUserEmail)
        }

        do {
            let response = try await networkManager.deleteWorkoutExercise(
                sessionId: workoutId,
                exerciseId: exerciseInstanceId,
                userEmail: userEmail
            )

            let previousLog = log
            let syncable = SyncableWorkoutSession(serverWorkout: response.workout)
            if let existingSession = try workoutDataManager.workoutSession(remoteId: response.workout.id, context: context) {
                existingSession.updateFromSyncable(syncable)
            } else {
                let newSession = WorkoutSession(from: syncable)
                context.insert(newSession)
            }

            if context.hasChanges {
                do {
                    try context.save()
                } catch {
                    print("⚠️ Failed to save workout context after exercise deletion: \(error)")
                }
            }

            var mergedLog = response.combinedLog
            mergedLog.message = previousLog.message
            mergedLog.logDate = previousLog.logDate
            mergedLog.scheduledAt = previousLog.scheduledAt
            if let updatedWorkout = mergedLog.workout {
                mergedLog.workout = updatedWorkout
            }

            withAnimation(.easeInOut) {
                detail = WorkoutLogDetailDisplay(
                    workout: response.workout,
                    log: mergedLog,
                    units: unitsSystem
                )
            }

            CombinedLogsRepository.shared.applyExternalUpdate(log: mergedLog)
            NotificationCenter.default.post(name: Notification.Name("LogsChangedNotification"), object: nil)

            return .success("\(exercise.name) was removed from this workout.")
        } catch {
            return .failure(error)
        }
    }

    private func loadDetail(using context: ModelContext, force: Bool) async {
        unitsSystem = Self.resolveUnitsSystem()

        if detail != nil && !force {
            return
        }

        if isLoading { return }
        isLoading = true
        errorMessage = nil

        defer { isLoading = false }

        guard log.activity == nil else {
            detail = nil
            return
        }

        guard let resolvedWorkoutId = resolveWorkoutId() else {
            if let fallback = try? detailFromApproximateLocal(context: context) {
                detail = fallback
            } else if !log.isOptimistic {
                #if DEBUG
                print("[WorkoutDetail] Missing workout identifier for log \(log.id)")
                #endif
                errorMessage = DetailError.missingWorkoutIdentifier.errorDescription
                detail = WorkoutLogDetailDisplay.makeFallback(from: log, units: unitsSystem)
            } else {
                detail = nil
            }
            return
        }

        if let localDetail = try? detailFromLocal(context: context, remoteId: resolvedWorkoutId) {
            #if DEBUG
            print("[WorkoutDetail] Using local detail for workout \(resolvedWorkoutId)")
            #endif
            detail = localDetail
            if !force {
                return
            }
        } else if let fallback = try? detailFromApproximateLocal(context: context) {
            #if DEBUG
            print("[WorkoutDetail] Using approximate local detail for workout \(resolvedWorkoutId)")
            #endif
            detail = fallback
            if !force {
                return
            }
        } else if !log.isOptimistic {
            #if DEBUG
            print("[WorkoutDetail] No local detail found, using fallback for workout \(resolvedWorkoutId)")
            #endif
            detail = WorkoutLogDetailDisplay.makeFallback(from: log, units: unitsSystem)
        }

        do {
            #if DEBUG
            print("[WorkoutDetail] Fetching remote detail workoutId=\(resolvedWorkoutId)")
            #endif
            let remoteDetail = try await detailFromRemote(workoutId: resolvedWorkoutId)
            detail = remoteDetail
            errorMessage = nil
        } catch {
            #if DEBUG
            print("[WorkoutDetail] Remote fetch failed for workoutId=\(resolvedWorkoutId) error=\(error)")
            #endif
            if detail == nil {
                if let fallback = try? detailFromApproximateLocal(context: context) {
                    detail = fallback
                } else if !log.isOptimistic {
                    detail = WorkoutLogDetailDisplay.makeFallback(from: log, units: unitsSystem)
                }
            }
            errorMessage = error.localizedDescription
        }
    }

    private func detailFromLocal(context: ModelContext, remoteId: Int) throws -> WorkoutLogDetailDisplay? {
        guard let session = try workoutDataManager.workoutSession(remoteId: remoteId, context: context) else {
            return nil
        }
        return WorkoutLogDetailDisplay(
            workout: session,
            log: log,
            units: unitsSystem
        )
    }

    private func detailFromApproximateLocal(context: ModelContext) throws -> WorkoutLogDetailDisplay? {
        let userEmail = WorkoutLogDetailViewModel.resolveUserEmail()
        let predicate: Predicate<WorkoutSession>? = userEmail.map { email in
            #Predicate { session in
                session.userEmail == email && session.isDeleted == false
            }
        }

        let descriptor = FetchDescriptor<WorkoutSession>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.completedAt, order: .reverse), SortDescriptor(\.startedAt, order: .reverse)]
        )

        let sessions = try context.fetch(descriptor)
        guard !sessions.isEmpty else { return nil }

        if let scheduled = log.workout?.scheduledAt ?? log.scheduledAt {
            let window: TimeInterval = 15 * 60
            if let match = sessions.first(where: { session in
                guard let completed = session.completedAt else { return false }
                return abs(completed.timeIntervalSince(scheduled)) <= window
            }) {
                return WorkoutLogDetailDisplay(workout: match, log: log, units: unitsSystem)
            }
        }

        if let first = sessions.first {
            return WorkoutLogDetailDisplay(workout: first, log: log, units: unitsSystem)
        }
        return nil
    }

    private func detailFromRemote(workoutId: Int) async throws -> WorkoutLogDetailDisplay {
        guard let email = WorkoutLogDetailViewModel.resolveUserEmail() else {
            throw DetailError.missingUserEmail
        }
        let response = try await networkManager.fetchWorkoutDetail(sessionId: workoutId, userEmail: email)
        return WorkoutLogDetailDisplay(
            workout: response,
            log: log,
            units: unitsSystem
        )
    }

    private func resolveWorkoutId() -> Int? {
        if let explicit = log.workoutLogId {
            return explicit
        }
        if let summaryId = log.workout?.id {
            return summaryId
        }
        return nil
    }

    private static func resolveUnitsSystem() -> UnitsSystem {
        if let stored = UserDefaults.standard.string(forKey: "unitsSystem"),
           let system = UnitsSystem(rawValue: stored) {
            return system
        }
        return .imperial
    }

    private static func resolveUserEmail() -> String? {
        guard let email = UserDefaults.standard.string(forKey: "userEmail"),
              !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        return email
    }

    enum DetailError: LocalizedError {
        case missingUserEmail
        case missingWorkoutIdentifier

        var errorDescription: String? {
            switch self {
            case .missingUserEmail:
                return "Missing user email for workout lookup."
            case .missingWorkoutIdentifier:
                return "This workout does not have an identifier yet."
            }
        }
    }

    enum DeleteError: LocalizedError {
        case missingExerciseIdentifier

        var errorDescription: String? {
            switch self {
            case .missingExerciseIdentifier:
                return "Unable to identify this exercise for deletion."
            }
        }
    }
}

struct WorkoutLogDetailDisplay {
    struct Exercise: Identifiable {
        struct SetDisplay: Identifiable {
            let id: String
            let summary: ExerciseSetSummary
            let note: String?
            let isCompleted: Bool
            let distanceUnit: DistanceUnit?
        }

        let id: String
        let instanceId: Int?
        let exerciseId: Int?
        let name: String
        let exerciseData: ExerciseData?
        let setDisplays: [SetDisplay]
        let historyExercise: TodayWorkoutExercise?
        let notes: String?

        var trimmedNotes: String? {
            WorkoutLogDetailDisplay.trimmedOrNil(notes)
        }
    }

    let title: String
    let completedAt: Date?
    let durationSeconds: TimeInterval?
    let calories: Int?
    let totalVolumeKg: Double
    let unitsSystem: UnitsSystem
    let notes: String?
    let exercises: [Exercise]
    let fallbackExerciseCount: Int?
    let fallbackSetCount: Int?
    let isHealthKitImport: Bool

    var trimmedNotes: String? {
        WorkoutLogDetailDisplay.trimmedOrNil(notes)
    }

    var hasExerciseDetail: Bool {
        exercises.contains { !$0.setDisplays.isEmpty }
    }

    var completedDateString: String? {
        guard let completedAt,
              completedAt.timeIntervalSince1970 > 0 else { return nil }
        return WorkoutLogDetailDisplay.dateFormatter.string(from: completedAt)
    }

    var durationString: String {
        WorkoutLogDetailDisplay.formatDuration(seconds: durationSeconds)
    }

    var volumeString: String {
        WorkoutLogDetailDisplay.formatVolume(totalVolumeKg: totalVolumeKg, units: unitsSystem)
    }

    var caloriesString: String {
        WorkoutLogDetailDisplay.formatCalories(calories)
    }

    var totalSets: Int {
        exercises.reduce(0) { $0 + $1.setDisplays.count }
    }

    var exerciseCount: Int {
        exercises.count
    }

    var exerciseSummaryString: String {
        if totalSets > 0 {
            let exerciseLabel = exerciseCount == 1 ? "exercise" : "exercises"
            let setsLabel = totalSets == 1 ? "set" : "sets"
            return "\(exerciseCount) \(exerciseLabel) · \(totalSets) \(setsLabel)"
        }

        if let fallbackCount = fallbackExerciseCount {
            let exerciseLabel = fallbackCount == 1 ? "exercise" : "exercises"
            if let fallbackSets = fallbackSetCount, fallbackSets > 0 {
                let setsLabel = fallbackSets == 1 ? "set" : "sets"
                return "\(fallbackCount) \(exerciseLabel) · \(fallbackSets) \(setsLabel)"
            }
            return "\(fallbackCount) \(exerciseLabel)"
        }

        return "No exercise data"
    }

    init(title: String,
         completedAt: Date?,
         durationSeconds: TimeInterval?,
         calories: Int?,
         totalVolumeKg: Double,
         unitsSystem: UnitsSystem,
         notes: String?,
         exercises: [Exercise],
         fallbackExerciseCount: Int?,
         fallbackSetCount: Int?,
         isHealthKitImport: Bool) {
        self.title = title
        self.completedAt = WorkoutLogDetailDisplay.sanitizedDate(completedAt)
        self.durationSeconds = durationSeconds
        self.calories = calories
        self.totalVolumeKg = totalVolumeKg
        self.unitsSystem = unitsSystem
        self.notes = WorkoutLogDetailDisplay.trimmedOrNil(notes)
        self.exercises = exercises
        self.fallbackExerciseCount = fallbackExerciseCount
        self.fallbackSetCount = fallbackSetCount
        self.isHealthKitImport = isHealthKitImport
    }

    init(workout: WorkoutSession, log: CombinedLog, units: UnitsSystem) {
        title = workout.name
        completedAt = WorkoutLogDetailDisplay.sanitizedDate(workout.completedAt)
        durationSeconds = workout.totalDuration ?? workout.duration
        calories = Int(log.displayCalories.rounded())
        unitsSystem = units
        notes = WorkoutLogDetailDisplay.trimmedOrNil(workout.notes)
        isHealthKitImport = false

        var totalVolumeKg: Double = 0
        var collectedExercises: [Exercise] = []

        let sortedExercises = workout.exercises.sorted { $0.orderIndex < $1.orderIndex }

        for exercise in sortedExercises {
            let (setDisplays, exerciseVolumeKg, historyExercise) = WorkoutLogDetailDisplay.buildSetDisplays(for: exercise, units: units)
            totalVolumeKg += exerciseVolumeKg

            let exerciseData = historyExercise?.exercise ?? WorkoutLogDetailDisplay.exerciseData(for: exercise.exerciseId)
            let display = Exercise(
                id: exercise.id.uuidString,
                instanceId: nil,
                exerciseId: exercise.exerciseId,
                name: exercise.exerciseName,
                exerciseData: exerciseData,
                setDisplays: setDisplays,
                historyExercise: historyExercise,
                notes: nil
            )

            collectedExercises.append(display)
        }

        self.totalVolumeKg = totalVolumeKg
        exercises = collectedExercises
        fallbackExerciseCount = log.workout?.exercisesCount ?? collectedExercises.count
        fallbackSetCount = collectedExercises.reduce(0) { $0 + $1.setDisplays.count }
    }

    init(workout: NetworkManagerTwo.WorkoutResponse.Workout, log: CombinedLog, units: UnitsSystem) {
        title = workout.name
        completedAt = WorkoutLogDetailDisplay.sanitizedDate(workout.completedAt)
        if let actualMinutes = workout.actualDurationMinutes {
            durationSeconds = TimeInterval(actualMinutes * 60)
        } else if let startedAt = workout.startedAt, let completedAt = workout.completedAt {
            durationSeconds = max(completedAt.timeIntervalSince(startedAt), 0)
        } else {
            durationSeconds = nil
        }
        calories = Int(log.displayCalories.rounded())
        unitsSystem = units
        notes = WorkoutLogDetailDisplay.trimmedOrNil(workout.notes)
        isHealthKitImport = false

        var totalVolumeKg: Double = 0
        var collectedExercises: [Exercise] = []

        let sortedExercises = workout.exercises.sorted { ($0.orderIndex ?? 0) < ($1.orderIndex ?? 0) }

        for exercise in sortedExercises {
            let (setDisplays, exerciseVolumeKg, historyExercise) = WorkoutLogDetailDisplay.buildSetDisplays(for: exercise, units: units)
            totalVolumeKg += exerciseVolumeKg

            let exerciseData = historyExercise?.exercise ?? WorkoutLogDetailDisplay.exerciseData(for: exercise.exerciseId)
            let display = Exercise(
                id: "\(exercise.id)",
                instanceId: exercise.id,
                exerciseId: exercise.exerciseId,
                name: exercise.exerciseName,
                exerciseData: exerciseData,
                setDisplays: setDisplays,
                historyExercise: historyExercise,
                notes: WorkoutLogDetailDisplay.trimmedOrNil(exercise.notes)
            )

            collectedExercises.append(display)
        }

        self.totalVolumeKg = totalVolumeKg
        exercises = collectedExercises
        fallbackExerciseCount = log.workout?.exercisesCount ?? workout.exercises.count
        fallbackSetCount = workout.exercises.reduce(0) { $0 + $1.sets.count }
    }

    static func makeFallback(from log: CombinedLog, units: UnitsSystem) -> WorkoutLogDetailDisplay {
        let workout = log.workout

        var durationSeconds: TimeInterval?
        if let seconds = workout?.durationSeconds, seconds > 0 {
            durationSeconds = TimeInterval(seconds)
        } else if let minutes = workout?.durationMinutes, minutes > 0 {
            durationSeconds = TimeInterval(minutes * 60)
        } else if let activityDuration = log.activity?.duration {
            durationSeconds = activityDuration
        }

        let completedAt = WorkoutLogDetailDisplay.sanitizedDate(workout?.scheduledAt ?? log.activity?.endDate)
        let exercisesCount = workout?.exercisesCount

        return WorkoutLogDetailDisplay(
            title: workout?.title ?? log.activity?.displayName ?? log.message,
            completedAt: completedAt,
            durationSeconds: durationSeconds,
            calories: Int(log.displayCalories.rounded()),
            totalVolumeKg: 0,
            unitsSystem: units,
            notes: nil,
            exercises: [],
            fallbackExerciseCount: exercisesCount,
            fallbackSetCount: nil,
            isHealthKitImport: log.activity != nil
        )
    }

    private static let exerciseLookup: [Int: ExerciseData] = {
        let exercises = ExerciseDatabase.getAllExercises()
        return Dictionary(uniqueKeysWithValues: exercises.map { ($0.id, $0) })
    }()

    private static func exerciseData(for id: Int?) -> ExerciseData? {
        guard let id else { return nil }
        return exerciseLookup[id]
    }

    private static func buildSetDisplays(for exercise: ExerciseInstance, units: UnitsSystem) -> ([Exercise.SetDisplay], Double, TodayWorkoutExercise?) {
        let exerciseData = exerciseData(for: exercise.exerciseId)
        let decodedFlexibleSets: [FlexibleSetData] = {
            guard let data = exercise.flexibleSetsData else { return [] }
            return (try? JSONDecoder().decode([FlexibleSetData].self, from: data)) ?? []
        }()

        var flexSets = decodedFlexibleSets
        if flexSets.isEmpty {
            flexSets = exercise.sets.sorted { $0.setNumber < $1.setNumber }
                .compactMap { makeFlexibleSet(from: $0, units: units) }
        }

        return makeDisplayPayload(
            flexSets: flexSets,
            exerciseData: exerciseData,
            notes: nil,
            units: units
        )
    }

    private static func buildSetDisplays(for exercise: NetworkManagerTwo.WorkoutResponse.Exercise, units: UnitsSystem) -> ([Exercise.SetDisplay], Double, TodayWorkoutExercise?) {
        let exerciseData = exerciseData(for: exercise.exerciseId)
        let flexSets = exercise.sets
            .compactMap { makeFlexibleSet(from: $0, units: units) }

        return makeDisplayPayload(
            flexSets: flexSets,
            exerciseData: exerciseData,
            notes: trimmedOrNil(exercise.notes),
            units: units
        )
    }

    private struct SetSummaryEntry {
        let summary: ExerciseSetSummary
        let flex: FlexibleSetData
    }

    private static func makeDisplayPayload(flexSets: [FlexibleSetData],
                                           exerciseData: ExerciseData?,
                                           notes: String?,
                                           units: UnitsSystem) -> ([Exercise.SetDisplay], Double, TodayWorkoutExercise?) {
        guard !flexSets.isEmpty else {
            let history = exerciseData.map { data in
                TodayWorkoutExercise(
                    exercise: data,
                    sets: 0,
                    reps: 0,
                    weight: nil,
                    restTime: 60,
                    notes: notes,
                    warmupSets: nil,
                    flexibleSets: [],
                    trackingType: nil
                )
            }
            return ([], 0, history)
        }

        let activeFlexSets = flexSets.filter { !$0.isWarmupSet }
        let summaries = loggedSummaries(from: activeFlexSets)
        var displays: [Exercise.SetDisplay] = []
        var volumeKg: Double = 0

        for entry in summaries {
            let summary = entry.summary
            if summary.trackingType == .repsWeight,
               let reps = summary.reps,
               let weight = summary.weight {
                let weightKg = units == .metric ? weight : weight / 2.2046226218
                volumeKg += reps * weightKg
            }

            let display = Exercise.SetDisplay(
                id: entry.flex.id.uuidString,
                summary: summary,
                note: entry.flex.notes,
                isCompleted: entry.flex.isActuallyCompleted,
                distanceUnit: entry.flex.distanceUnit
            )
            displays.append(display)
        }

        let historyExercise: TodayWorkoutExercise? = exerciseData.map { data in
            let loggedSetsCount = summaries.count
            let repsValue = summaries.compactMap { $0.summary.reps.map { Int(round($0)) } }.first ?? 0
            let weightValue = summaries.compactMap { $0.summary.weight }.first
            let restTime = (activeFlexSets.first?.restTime ?? flexSets.first?.restTime) ?? 60
            let trackingType = (activeFlexSets.first ?? flexSets.first)?.trackingType

            return TodayWorkoutExercise(
                exercise: data,
                sets: loggedSetsCount,
                reps: repsValue,
                weight: weightValue,
                restTime: restTime,
                notes: notes,
                warmupSets: nil,
                flexibleSets: activeFlexSets,
                trackingType: trackingType
            )
        }

        return (displays, volumeKg, historyExercise)
    }

    private static func loggedSummaries(from flexSets: [FlexibleSetData]) -> [SetSummaryEntry] {
        var results: [SetSummaryEntry] = []
        for flex in flexSets where !flex.isWarmupSet {
            let index = results.count + 1
            let trackingType = flex.trackingType

            switch trackingType {
            case .repsWeight:
                guard let reps = parseDouble(flex.reps), reps > 0 else { continue }
                let rawWeight = parseDouble(flex.weight)
                let sanitizedWeight: Double? = {
                    guard let weight = rawWeight, weight > 0 else { return nil }
                    return weight
                }()
                let summary = ExerciseSetSummary(index: index,
                                                  trackingType: .repsWeight,
                                                  reps: reps,
                                                  weight: sanitizedWeight,
                                                  duration: nil,
                                                  distance: nil)
                results.append(SetSummaryEntry(summary: summary, flex: flex))

            case .repsOnly:
                guard let reps = parseDouble(flex.reps), reps > 0 else { continue }
                let summary = ExerciseSetSummary(index: index,
                                                  trackingType: .repsOnly,
                                                  reps: reps,
                                                  weight: nil,
                                                  duration: nil,
                                                  distance: nil)
                results.append(SetSummaryEntry(summary: summary, flex: flex))

            case .timeOnly, .holdTime:
                guard let duration = flex.duration, duration > 0 else { continue }
                let summary = ExerciseSetSummary(index: index,
                                                  trackingType: trackingType,
                                                  reps: nil,
                                                  weight: nil,
                                                  duration: duration,
                                                  distance: nil)
                results.append(SetSummaryEntry(summary: summary, flex: flex))

            case .timeDistance:
                let duration = flex.duration
                let distance = flex.distance
                guard (duration ?? 0) > 0 || (distance ?? 0) > 0 else { continue }
                let summary = ExerciseSetSummary(index: index,
                                                  trackingType: .timeDistance,
                                                  reps: nil,
                                                  weight: nil,
                                                  duration: duration,
                                                  distance: distance)
                results.append(SetSummaryEntry(summary: summary, flex: flex))

            case .rounds:
                let rounds = flex.rounds ?? parseDouble(flex.reps).map { Int(round($0)) }
                guard let rounds, rounds > 0 else { continue }
                let summary = ExerciseSetSummary(index: index,
                                                  trackingType: .rounds,
                                                  reps: Double(rounds),
                                                  weight: nil,
                                                  duration: flex.duration,
                                                  distance: nil)
                results.append(SetSummaryEntry(summary: summary, flex: flex))
            }
        }
        return results
    }

    private static func makeFlexibleSet(from set: SetInstance, units: UnitsSystem) -> FlexibleSetData? {
        let trackingType = detectTrackingType(reps: set.actualReps ?? set.targetReps,
                                              weightKg: set.actualWeight ?? set.targetWeight,
                                              durationSeconds: set.durationSeconds,
                                              distanceMeters: set.distanceMeters,
                                              trackingHint: set.trackingTypeRawValue)
        var flex = FlexibleSetData(trackingType: trackingType)
        if let explicitType = set.trackingType {
            flex.trackingType = explicitType
        }

        let repsValue = set.actualReps ?? set.targetReps
        if repsValue > 0 {
            flex.reps = String(repsValue)
            if flex.trackingType == .rounds {
                flex.rounds = repsValue
            }
        }

        if let weightValue = set.actualWeight ?? set.targetWeight, weightValue > 0 {
            let displayWeight = units == .metric ? weightValue : weightValue
            flex.weight = formattedNumber(displayWeight)
        }

        if let duration = set.durationSeconds, duration > 0 {
            let durationValue = TimeInterval(duration)
            flex.duration = durationValue
            flex.durationString = clockDurationString(durationValue)
        }

        if let distance = set.distanceMeters, distance > 0 {
            let converted = convertDistanceToDisplay(distance, units: units)
            flex.distance = converted.value
            flex.distanceUnit = converted.unit
        }

        flex.isCompleted = set.isCompleted
        flex.wasLogged = set.completed
        flex.isWarmupSet = false
        flex.notes = set.notes

        if flex.reps == nil && flex.weight == nil && flex.duration == nil && flex.distance == nil && (flex.rounds ?? 0) <= 0 {
            return nil
        }

        return flex
    }

    private static func makeFlexibleSet(from set: NetworkManagerTwo.WorkoutResponse.ExerciseSet, units: UnitsSystem) -> FlexibleSetData? {
        let trackingType = detectTrackingType(reps: set.reps,
                                              weightKg: set.weightKg,
                                              durationSeconds: set.durationSeconds,
                                              distanceMeters: set.distanceMeters,
                                              trackingHint: set.trackingType)
        var flex = FlexibleSetData(trackingType: trackingType)

        if let reps = set.reps, reps > 0 {
            flex.reps = String(reps)
        }

        if let weightKg = set.weightKg, weightKg > 0 {
            let displayWeight = units == .metric ? weightKg : weightKg * 2.2046226218
            flex.weight = formattedNumber(displayWeight)
        }

        if let duration = set.durationSeconds, duration > 0 {
            let durationValue = TimeInterval(duration)
            flex.duration = durationValue
            flex.durationString = clockDurationString(durationValue)
        }

        if let distance = set.distanceMeters, distance > 0 {
            let converted = convertDistanceToDisplay(distance, units: units)
            flex.distance = converted.value
            flex.distanceUnit = converted.unit
        }

        if let rounds = set.roundsCompleted, rounds > 0 {
            flex.rounds = rounds
        }

        flex.isCompleted = set.isCompleted ?? false
        flex.wasLogged = set.isCompleted
        flex.isWarmupSet = set.isWarmup ?? false
        flex.notes = trimmedOrNil(set.notes)
        flex.restTime = set.restSeconds

        if flex.reps == nil && flex.weight == nil && flex.duration == nil && flex.distance == nil && (flex.rounds ?? 0) <= 0 {
            return nil
        }

        return flex
    }

    private static func detectTrackingType(reps: Int?, weightKg: Double?, durationSeconds: Int?, distanceMeters: Double?, trackingHint: String?) -> ExerciseTrackingType {
        if let hint = trackingHint, let type = ExerciseTrackingType(rawValue: hint) {
            return type
        }

        if let durationSeconds, durationSeconds > 0, let distanceMeters, distanceMeters > 0 {
            return .timeDistance
        }
        if let durationSeconds, durationSeconds > 0 {
            return .timeOnly
        }
        if let distanceMeters, distanceMeters > 0 {
            return .timeDistance
        }
        if let weightKg, weightKg > 0, let reps, reps > 0 {
            return .repsWeight
        }
        if let reps, reps > 0 {
            return .repsOnly
        }
        if let weightKg, weightKg > 0 {
            return .repsWeight
        }
        return .repsOnly
    }

    private static func parseDouble(_ value: String?) -> Double? {
        guard let raw = value?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else { return nil }
        let filtered = raw.filter { "0123456789.,-".contains($0) }
        guard !filtered.isEmpty else { return nil }
        let normalized = filtered.replacingOccurrences(of: ",", with: ".")
        return Double(normalized)
    }

    private static func formattedNumber(_ value: Double) -> String {
        if abs(value.rounded() - value) < 0.0001 {
            return String(format: "%.0f", value)
        }
        return String(format: "%.2f", value)
    }

    private static func convertDistanceToDisplay(_ meters: Double, units: UnitsSystem) -> (value: Double, unit: DistanceUnit) {
        switch units {
        case .metric:
            return (meters / 1000.0, .kilometers)
        case .imperial:
            return (meters * 0.000621371, .miles)
        }
    }

    private static func clockDurationString(_ duration: TimeInterval) -> String {
        let totalSeconds = Int(duration.rounded())
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        if minutes > 0 {
            return String(format: "%d:%02d", minutes, seconds)
        }
        return String(format: "0:%02d", seconds)
    }

    private static func formatDuration(seconds: TimeInterval?) -> String {
        guard let rawSeconds = seconds, rawSeconds > 0 else { return "—" }
        let totalSeconds = Int(rawSeconds)
        if totalSeconds < 60 {
            return "\(totalSeconds)s"
        }

        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        var components: [String] = []
        if hours > 0 {
            components.append("\(hours) hr")
        }
        if minutes > 0 {
            components.append("\(minutes) min")
        }
        if seconds > 0 {
            components.append(hours > 0 ? "\(seconds) sec" : "\(seconds)s")
        }

        return components.joined(separator: " ")
    }

    private static func formatVolume(totalVolumeKg: Double, units: UnitsSystem) -> String {
        guard totalVolumeKg > 0 else { return "0 \(units.weightSymbol)" }
        let converted = units.convertWeight(fromKilograms: totalVolumeKg)
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = converted < 100 ? 1 : 0
        let value = formatter.string(from: NSNumber(value: converted)) ?? String(format: "%.0f", converted)
        return "\(value) \(units.weightSymbol)"
    }

    private static func formatCalories(_ calories: Int?) -> String {
        guard let calories else { return "—" }
        return "\(calories) cal"
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    private static func trimmedOrNil(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else { return nil }
        return trimmed
    }

    private static func sanitizedDate(_ date: Date?) -> Date? {
        guard let date else { return nil }
        // Treat near-epoch values as missing to avoid showing "Dec 31, 1969"
        let minimumValidTimestamp: TimeInterval = 60 // one minute past epoch to account for offsets
        return date.timeIntervalSince1970 >= minimumValidTimestamp ? date : nil
    }
}

private extension UnitsSystem {
    var weightSymbol: String {
        switch self {
        case .metric: return "kg"
        case .imperial: return "lb"
        }
    }

    func convertWeight(fromKilograms value: Double) -> Double {
        switch self {
        case .metric:
            return value
        case .imperial:
            return value * 2.2046226218
        }
    }
}
