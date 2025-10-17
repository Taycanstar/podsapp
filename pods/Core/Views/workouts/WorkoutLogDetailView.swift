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
        .navigationTitle("Workout Detail")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color("primarybg").ignoresSafeArea())
        .task {
            await viewModel.load(using: modelContext)
        }
    }

    private var detailContent: some View {
        let display = viewModel.detail ?? WorkoutLogDetailDisplay.makeFallback(from: log, units: viewModel.unitsSystem)

        return ScrollView {
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
                        unitsSymbol: detail.unitsSystem.weightSymbol
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

    @State private var showHistory = false
    @State private var alertMessage: String?
    @State private var isShowingAlert = false
    @State private var historyExercise: TodayWorkoutExercise?

    init(exercise: WorkoutLogDetailDisplay.Exercise, unitsSymbol: String) {
        self.exercise = exercise
        self.unitsSymbol = unitsSymbol
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
                                if let line = setLine(for: set.summary) {
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
            if let payload = historyExercise {
                ExerciseHistory(exercise: payload)
            }
        }
        .alert("Workout detail", isPresented: $isShowingAlert, actions: {
            Button("OK", role: .cancel) { }
        }, message: {
            Text(alertMessage ?? "")
        })
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
                guard let payload = makeHistoryExercise() else {
                    alertMessage = "Exercise history is unavailable for this entry."
                    isShowingAlert = true
                    return
                }
                historyExercise = payload
                showHistory = true
            }

            if let exerciseId = exercise.exerciseId {
                Button("Recommend more often") {
                    UserProfileService.shared.setExercisePreferenceMoreOften(exerciseId: exerciseId)
                    alertMessage = "We'll recommend \(exercise.name) more frequently."
                    isShowingAlert = true
                }

                Button("Recommend less often") {
                    UserProfileService.shared.setExercisePreferenceLessOften(exerciseId: exerciseId)
                    alertMessage = "We'll recommend \(exercise.name) less often."
                    isShowingAlert = true
                }

                Button("Don't recommend again", role: .destructive) {
                    UserProfileService.shared.addToAvoided(exerciseId)
                    alertMessage = "\(exercise.name) won't be recommended again."
                    isShowingAlert = true
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

            Button("Delete from workout", role: .destructive) {
                alertMessage = "Completed workouts cannot be edited from this view."
                isShowingAlert = true
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

    private func makeHistoryExercise() -> TodayWorkoutExercise? {
        guard let data = exercise.exerciseData else { return nil }

        let setsCount = max(exercise.setDisplays.count, 1)
        let repsSamples = exercise.setDisplays.compactMap { display -> Int? in
            guard let reps = display.summary.reps else { return nil }
            let rounded = Int(round(reps))
            return rounded > 0 ? rounded : nil
        }
        let repsValue = repsSamples.first ?? 0
        let weightValue = exercise.setDisplays.compactMap { $0.summary.weight }.first
        let trackingType = exercise.setDisplays.first?.summary.trackingType

        return TodayWorkoutExercise(
            exercise: data,
            sets: setsCount,
            reps: repsValue,
            weight: weightValue,
            restTime: 60,
            notes: exercise.notes,
            warmupSets: nil,
            flexibleSets: nil,
            trackingType: trackingType
        )
    }

    private func setLine(for summary: ExerciseSetSummary) -> String? {
        let repsValue = summary.reps.map { Int(round($0)) }

        switch summary.trackingType {
        case .repsWeight:
            guard let reps = repsValue, reps > 0,
                  let weight = summary.weight else { return nil }
            return "\(reps) reps x \(formattedWeight(weight)) \(unitsSymbol)"
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
                let value = formatter.string(from: NSNumber(value: distance)) ?? "\(distance)"
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

        guard let workoutId = resolveWorkoutId() else {
            if !log.isOptimistic {
                errorMessage = DetailError.missingWorkoutIdentifier.errorDescription
            }
            detail = nil
            return
        }

        do {
            if let localDetail = try detailFromLocal(context: context, remoteId: workoutId) {
                detail = localDetail
                return
            }

            let remoteDetail = try await detailFromRemote(workoutId: workoutId)
            detail = remoteDetail
        } catch {
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
}

struct WorkoutLogDetailDisplay {
    struct Exercise: Identifiable {
        struct SetDisplay: Identifiable {
            let id: String
            let summary: ExerciseSetSummary
            let note: String?
            let isCompleted: Bool
        }

        let id: String
        let exerciseId: Int?
        let name: String
        let exerciseData: ExerciseData?
        let setDisplays: [SetDisplay]
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
        guard let completedAt else { return nil }
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
        self.completedAt = completedAt
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
        completedAt = workout.completedAt
        durationSeconds = workout.totalDuration ?? workout.duration
        calories = Int(log.displayCalories.rounded())
        unitsSystem = units
        notes = WorkoutLogDetailDisplay.trimmedOrNil(workout.notes)
        isHealthKitImport = false

        var totalVolumeKg: Double = 0
        var collectedExercises: [Exercise] = []

        let sortedExercises = workout.exercises.sorted { $0.orderIndex < $1.orderIndex }

        for exercise in sortedExercises {
            let (setDisplays, exerciseVolumeKg) = WorkoutLogDetailDisplay.buildSetDisplays(for: exercise, units: units)
            totalVolumeKg += exerciseVolumeKg

            let display = Exercise(
                id: exercise.id.uuidString,
                exerciseId: exercise.exerciseId,
                name: exercise.exerciseName,
                exerciseData: WorkoutLogDetailDisplay.exerciseData(for: exercise.exerciseId),
                setDisplays: setDisplays,
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
        completedAt = workout.completedAt
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
            let (setDisplays, exerciseVolumeKg) = WorkoutLogDetailDisplay.buildSetDisplays(for: exercise, units: units)
            totalVolumeKg += exerciseVolumeKg

            let display = Exercise(
                id: "\(exercise.id)",
                exerciseId: exercise.exerciseId,
                name: exercise.exerciseName,
                exerciseData: WorkoutLogDetailDisplay.exerciseData(for: exercise.exerciseId),
                setDisplays: setDisplays,
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

        let completedAt = workout?.scheduledAt ?? log.activity?.endDate
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

    private static func buildSetDisplays(for exercise: ExerciseInstance, units: UnitsSystem) -> ([Exercise.SetDisplay], Double) {
        let sortedSets = exercise.sets.sorted { $0.setNumber < $1.setNumber }
        var displays: [Exercise.SetDisplay] = []
        var exerciseVolumeKg: Double = 0

        for set in sortedSets {
            if let result = summaryForLocalSet(set, units: units) {
                displays.append(result.display)
                exerciseVolumeKg += result.volumeContributionKg
            }
        }

        return (displays, exerciseVolumeKg)
    }

    private static func buildSetDisplays(for exercise: NetworkManagerTwo.WorkoutResponse.Exercise, units: UnitsSystem) -> ([Exercise.SetDisplay], Double) {
        let sortedSets = exercise.sets.enumerated()
        var displays: [Exercise.SetDisplay] = []
        var exerciseVolumeKg: Double = 0

        for (index, set) in sortedSets {
            if let result = summaryForRemoteSet(set, fallbackIndex: index, units: units) {
                displays.append(result.display)
                exerciseVolumeKg += result.volumeContributionKg
            }
        }

        return (displays, exerciseVolumeKg)
    }

    private static func summaryForLocalSet(_ set: SetInstance, units: UnitsSystem) -> (display: Exercise.SetDisplay, volumeContributionKg: Double)? {
        let repsValue = set.actualReps ?? set.targetReps ?? 0
        let weightKg = set.actualWeight ?? set.targetWeight
        let durationSeconds = set.durationSeconds
        let distanceMeters = set.distanceMeters

        let hasReps = repsValue > 0
        let hasWeight = (weightKg ?? 0) > 0
        let hasDuration = (durationSeconds ?? 0) > 0
        let hasDistance = (distanceMeters ?? 0) > 0

        guard hasReps || hasWeight || hasDuration || hasDistance else { return nil }

        let trackingType = trackingTypeForLocalSet(weightKg: weightKg, reps: repsValue, durationSeconds: durationSeconds, distanceMeters: distanceMeters)
        let displayWeight = convertWeightForDisplay(weightKg, units: units)
        let displayReps = hasReps ? Double(repsValue) : nil
        let displayDuration = durationSeconds.flatMap { $0 > 0 ? TimeInterval($0) : nil }
        let displayDistance = distanceMeters.flatMap { $0 > 0 ? $0 : nil }

        if displayReps == nil && displayWeight == nil && displayDuration == nil && displayDistance == nil {
            return nil
        }

        let summary = ExerciseSetSummary(
            index: set.setNumber,
            trackingType: trackingType,
            reps: displayReps,
            weight: displayWeight,
            duration: displayDuration,
            distance: displayDistance
        )

        let display = Exercise.SetDisplay(
            id: set.id.uuidString,
            summary: summary,
            note: trimmedOrNil(set.notes),
            isCompleted: set.isCompleted
        )

        let volumeContribution = (weightKg ?? 0) > 0 && hasReps ? Double(repsValue) * (weightKg ?? 0) : 0

        return (display, volumeContribution)
    }

    private static func summaryForRemoteSet(_ set: NetworkManagerTwo.WorkoutResponse.ExerciseSet, fallbackIndex: Int, units: UnitsSystem) -> (display: Exercise.SetDisplay, volumeContributionKg: Double)? {
        let repsValue = set.reps ?? 0
        let weightKg = set.weightKg
        let durationSeconds = set.durationSeconds
        let distanceMeters = set.distanceMeters

        let hasReps = repsValue > 0
        let hasWeight = (weightKg ?? 0) > 0
        let hasDuration = (durationSeconds ?? 0) > 0
        let hasDistance = (distanceMeters ?? 0) > 0

        guard hasReps || hasWeight || hasDuration || hasDistance else { return nil }

        let trackingType = trackingTypeForRemoteSet(rawValue: set.trackingType, weightKg: weightKg, reps: repsValue, durationSeconds: durationSeconds, distanceMeters: distanceMeters)
        let displayWeight = convertWeightForDisplay(weightKg, units: units)
        let displayReps = hasReps ? Double(repsValue) : nil
        let displayDuration = durationSeconds.flatMap { $0 > 0 ? TimeInterval($0) : nil }
        let displayDistance = distanceMeters.flatMap { $0 > 0 ? $0 : nil }

        if displayReps == nil && displayWeight == nil && displayDuration == nil && displayDistance == nil {
            return nil
        }

        let summary = ExerciseSetSummary(
            index: set.setNumber ?? fallbackIndex + 1,
            trackingType: trackingType,
            reps: displayReps,
            weight: displayWeight,
            duration: displayDuration,
            distance: displayDistance
        )

        let display = Exercise.SetDisplay(
            id: "\(summary.index)",
            summary: summary,
            note: trimmedOrNil(set.notes),
            isCompleted: set.isCompleted ?? false
        )

        let volumeContribution = (weightKg ?? 0) > 0 && hasReps ? Double(repsValue) * (weightKg ?? 0) : 0

        return (display, volumeContribution)
    }

    private static func trackingTypeForLocalSet(weightKg: Double?, reps: Int, durationSeconds: Int?, distanceMeters: Double?) -> ExerciseTrackingType {
        if let durationSeconds, durationSeconds > 0, let distanceMeters, distanceMeters > 0 {
            return .timeDistance
        }
        if let durationSeconds, durationSeconds > 0 {
            return .timeOnly
        }
        if let distanceMeters, distanceMeters > 0 {
            return .timeDistance
        }
        if let weightKg, weightKg > 0, reps > 0 {
            return .repsWeight
        }
        if reps > 0 {
            return .repsOnly
        }
        if let weightKg, weightKg > 0 {
            return .repsWeight
        }
        return .repsOnly
    }

    private static func trackingTypeForRemoteSet(rawValue: String?, weightKg: Double?, reps: Int, durationSeconds: Int?, distanceMeters: Double?) -> ExerciseTrackingType {
        if let rawValue, let type = ExerciseTrackingType(rawValue: rawValue) {
            return type
        }
        return trackingTypeForLocalSet(weightKg: weightKg, reps: reps, durationSeconds: durationSeconds, distanceMeters: distanceMeters)
    }

    private static func convertWeightForDisplay(_ weightKg: Double?, units: UnitsSystem) -> Double? {
        guard let weightKg, weightKg > 0 else { return nil }
        return units.convertWeight(fromKilograms: weightKg)
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
