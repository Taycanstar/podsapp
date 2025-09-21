import SwiftUI
import UIKit

struct WorkoutSummarySheet: View {
    let summary: CompletedWorkoutSummary
    @Environment(\.dismiss) private var dismiss

    private var unitsSymbol: String {
        summary.stats.unitsSystem == .metric ? "kg" : "lb"
    }

    private struct PersonalRecordDisplay: Identifiable {
        let id = UUID()
        let icon: String
        let title: String
        let detail: String
    }

    private struct ExerciseSection: Identifiable {
        let id = UUID()
        let title: String
        let exercises: [ExerciseBreakdown]
        let allowsFavorite: Bool
    }

    private var sections: [ExerciseSection] {
        let warmups = summary.exerciseBreakdown.filter { $0.section == .warmUp }
        let mains = summary.exerciseBreakdown.filter { $0.section == .main }
        let cooldowns = summary.exerciseBreakdown.filter { $0.section == .coolDown }

        return [
            ExerciseSection(title: "Warm-up", exercises: warmups, allowsFavorite: false),
            ExerciseSection(title: "Exercises", exercises: mains, allowsFavorite: true),
            ExerciseSection(title: "Cool-down", exercises: cooldowns, allowsFavorite: false)
        ].filter { !$0.exercises.isEmpty }
    }

    private var personalRecordDisplays: [PersonalRecordDisplay] {
        summary.stats.personalRecords.compactMap { record in
            guard record.recordType == .heaviestWeight,
                  let weight = record.weight,
                  weight > 0,
                  let setText = formattedSet(weight: weight, reps: record.reps) else { return nil }

            var detail = "Heaviest set · \(setText)"

            if let previous = record.previousWeight, previous > 0 {
                let previousSet = formattedSet(weight: previous, reps: record.previousReps)
                    ?? "\(formattedWeight(previous)) \(unitsSymbol)"
                detail += " (prev \(previousSet))"
            }

            return PersonalRecordDisplay(icon: "scalemass",
                                          title: record.exerciseName,
                                          detail: detail)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    statsHeader

                    if !personalRecordDisplays.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Personal Records")
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundStyle(.primary)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            prSection
                        }
                        .padding(.horizontal)
                    }

                    ForEach(sections) { section in
                        VStack(alignment: .leading, spacing: 12) {
                            Text(section.title)
                                .font(.title3)
                                .foregroundStyle(.primary)
                                .padding(.horizontal)
                                .fontWeight(.bold)

                            LazyVStack(spacing: 16) {
                                ForEach(section.exercises) { breakdown in
                                    ExerciseBreakdownRow(breakdown: breakdown,
                                                         unitsSymbol: unitsSymbol,
                                                         allowsFavorite: section.allowsFavorite)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
                .padding(.top, 24)
                .padding(.bottom, 32)
            }
            .background(Color("altbg"))
            .navigationTitle("Workout Complete")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "checkmark")
                            .font(.title2)
                            .foregroundStyle(Color.accentColor)
                    }
                    .accessibilityLabel("Dismiss workout summary")
                }
            }
        }
        .background(Color("altbg").ignoresSafeArea())
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private var statsHeader: some View {
        VStack(spacing: 16) {
            let durationDisplay = formattedSummaryDuration(summary.stats.duration)
            let volumeDisplay = "\(formattedVolume(summary.stats.totalVolume)) \(unitsSymbol)"
            let caloriesDisplay = formattedCalories(summary.stats.estimatedCalories)

            VStack(spacing: 6) {
                Text(summary.workout.title)
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)
                let loggedExerciseCount = summary.exerciseBreakdown.count
                let exerciseLabel = loggedExerciseCount == 1 ? "exercise" : "exercises"
                Text("\(formattedDate(summary.workout.date)) · \(loggedExerciseCount) \(exerciseLabel)")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 16) {
                StatTile(title: "Duration", value: durationDisplay)
                StatTile(title: "Volume", value: volumeDisplay)
                StatTile(title: "Calories", value: caloriesDisplay)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(
                  Color("altcard")
                )
        )
        .padding(.horizontal)
    }

    private var prSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(personalRecordDisplays) { record in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: record.icon)
                        .font(.callout)
                        .foregroundStyle(.primary)
                        .frame(width: 28, height: 28)
                       

                    VStack(alignment: .leading, spacing: 4) {
                        Text(record.title)
                            .font(.subheadline.bold())
                        Text(record.detail)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 0)
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color("altcard"))
        )
    }

    private func formattedSummaryDuration(_ duration: TimeInterval) -> String {
        let totalSeconds = max(Int(duration.rounded()), 0)
        if totalSeconds < 60 {
            return "\(totalSeconds) sec"
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
            components.append("\(seconds) sec")
        }

        return components.joined(separator: " ")
    }

    private func formattedVolume(_ volume: Double) -> String {
        guard volume > 0 else { return "0" }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: volume)) ?? "0"
    }

    private func formattedWeight(_ weight: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        let showsDecimal = summary.stats.unitsSystem == .metric && weight.truncatingRemainder(dividingBy: 1) != 0
        formatter.maximumFractionDigits = showsDecimal ? 1 : 0
        return formatter.string(from: NSNumber(value: weight)) ?? "0"
    }

    private func formattedSet(weight: Double?, reps: Int?) -> String? {
        if let weight, weight > 0, let reps, reps > 0 {
            return "\(formattedWeight(weight)) \(unitsSymbol) x \(reps)"
        }
        if let reps, reps > 0 {
            return "\(reps) reps"
        }
        return nil
    }

    private func formattedCalories(_ calories: Int) -> String {
        "\(calories) cal"
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

private struct StatTile: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.bold())
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color("altcard"))
        )
    }
}

private struct ExerciseBreakdownRow: View {
    let breakdown: ExerciseBreakdown
    let unitsSymbol: String
    let allowsFavorite: Bool

    @State private var isFavorite: Bool

    init(breakdown: ExerciseBreakdown, unitsSymbol: String, allowsFavorite: Bool) {
        self.breakdown = breakdown
        self.unitsSymbol = unitsSymbol
        self.allowsFavorite = allowsFavorite
        let bias = UserProfileService.shared.getExercisePreferenceBias(exerciseId: breakdown.exercise.id)
        _isFavorite = State(initialValue: allowsFavorite && bias > 0)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            thumbnail

            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top) {
                    Text(breakdown.exercise.name)
                        .font(.headline)

                    Spacer(minLength: 12)

                    if allowsFavorite {
                        favoriteButton
                    }
                }

                metricsView
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color("altbg"))
        )
    }

    private var thumbnail: some View {
        let imageId = String(format: "%04d", breakdown.exercise.id)
        return Group {
            if let image = UIImage(named: imageId) {
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

    private var favoriteButton: some View {
        Button {
            isFavorite.toggle()
            if isFavorite {
                UserProfileService.shared.setExercisePreferenceMoreOften(exerciseId: breakdown.exercise.id)
            } else {
                UserProfileService.shared.clearExercisePreference(exerciseId: breakdown.exercise.id)
            }
        } label: {
            Image(systemName: isFavorite ? "star.fill" : "star")
                .font(.title3)
                .foregroundStyle(isFavorite ? Color.accentColor : Color.secondary)
                .padding(6)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isFavorite ? "Favorite exercise" : "Mark exercise as favorite")
    }

    private var metricsView: some View {
        VStack(alignment: .leading, spacing: 6) {
            if !breakdown.setSummaries.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(breakdown.setSummaries.sorted(by: { $0.index < $1.index })) { set in
                        if let line = setLine(for: set) {
                            Text(line)
                                .font(.subheadline)
                                .foregroundStyle(.primary)
                        }
                    }
                }
            }

        }
    }

    private func formattedWeight(_ weight: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        let usesDecimal = unitsSymbol == "kg" && weight.truncatingRemainder(dividingBy: 1) != 0
        formatter.maximumFractionDigits = usesDecimal ? 1 : 0
        return formatter.string(from: NSNumber(value: weight)) ?? "0"
    }

    private func formattedDuration(_ duration: TimeInterval) -> String {
        clockDurationString(duration)
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
