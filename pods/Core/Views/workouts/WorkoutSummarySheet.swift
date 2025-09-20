import SwiftUI
import UIKit

struct WorkoutSummarySheet: View {
    let summary: CompletedWorkoutSummary
    @Environment(\.dismiss) private var dismiss

    private var unitsSymbol: String {
        summary.stats.unitsSystem == .metric ? "kg" : "lbs"
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
            ExerciseSection(title: "Workout", exercises: mains, allowsFavorite: true),
            ExerciseSection(title: "Cool-down", exercises: cooldowns, allowsFavorite: false)
        ].filter { !$0.exercises.isEmpty }
    }

    private var personalRecordDisplays: [PersonalRecordDisplay] {
        summary.stats.personalRecords.map { record in
            switch record.recordType {
            case .heaviestWeight:
                let value = formattedWeight(record.newValue)
                let previous = record.previousValue.map { formattedWeight($0) } ?? "—"
                return PersonalRecordDisplay(icon: "scalemass",
                                              title: record.exerciseName,
                                              detail: "Heaviest weight · \(value) \(unitsSymbol) (prev \(previous))")
            case .mostReps:
                let value = Int(record.newValue)
                let previous = record.previousValue.map { Int($0) }
                let previousText = previous != nil ? " (prev \(previous!))" : ""
                return PersonalRecordDisplay(icon: "repeat",
                                              title: record.exerciseName,
                                              detail: "Most reps · \(value) reps\(previousText)")
            case .bestVolume:
                let value = formattedVolume(record.newValue)
                let previous = record.previousValue.map { formattedVolume($0) } ?? "—"
                return PersonalRecordDisplay(icon: "chart.bar.fill",
                                              title: record.exerciseName,
                                              detail: "Highest volume · \(value) \(unitsSymbol) (prev \(previous))")
            }
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    statsHeader

                    if !personalRecordDisplays.isEmpty {
                        prSection
                    }

                    ForEach(sections) { section in
                        VStack(alignment: .leading, spacing: 12) {
                            Text(section.title)
                                .font(.headline)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal)

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
            // .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Workout Complete")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(Color.accentColor)
                    }
                    .accessibilityLabel("Dismiss workout summary")
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private var statsHeader: some View {
        VStack(spacing: 16) {
            VStack(spacing: 6) {
                Text(summary.workout.title)
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)
                Text("\(formattedDate(summary.workout.date)) · \(summary.stats.exerciseCount) exercises")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 16) {
                StatTile(title: "Duration",
                         value: formattedDuration(summary.stats.duration),
                         subtitle: "")
                StatTile(title: "Volume",
                         value: formattedVolume(summary.stats.totalVolume),
                         subtitle: unitsSymbol)
                StatTile(title: "Calories",
                         value: "\(summary.stats.estimatedCalories)",
                         subtitle: "kcal")
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(
                    LinearGradient(colors: [Color.accentColor.opacity(0.2), Color.accentColor.opacity(0.05)],
                                   startPoint: .topLeading,
                                   endPoint: .bottomTrailing)
                )
        )
        .padding(.horizontal)
    }

    private var prSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Personal Records", systemImage: "trophy.fill")
                .font(.headline)
                .foregroundStyle(Color.accentColor)

            ForEach(personalRecordDisplays) { record in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: record.icon)
                        .font(.callout)
                        .foregroundStyle(Color.accentColor)
                        .frame(width: 28, height: 28)
                        .background(
                            Circle()
                                .fill(Color.accentColor.opacity(0.12))
                        )

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
                .fill(Color(.secondarySystemBackground))
        )
        .padding(.horizontal)
    }

    private func formattedDuration(_ duration: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = duration >= 3600 ? [.hour, .minute] : [.minute, .second]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: duration) ?? "0m"
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
        formatter.maximumFractionDigits = weight.truncatingRemainder(dividingBy: 1) == 0 ? 0 : 1
        return formatter.string(from: NSNumber(value: weight)) ?? "0"
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
    let subtitle: String

    var body: some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.bold())
            if !subtitle.isEmpty {
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(.systemBackground).opacity(0.85))
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

            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(breakdown.exercise.name)
                            .font(.headline)
                        Text(breakdown.exercise.bodyPart)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 12)

                    if allowsFavorite {
                        favoriteButton
                    }
                }

                metricsRow

                if let topWeight = breakdown.topWeight {
                    Text("Top set · \(formattedWeight(topWeight)) \(unitsSymbol)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let average = breakdown.averageWeight,
                   let top = breakdown.topWeight,
                   average > 0,
                   abs(top - average) > 0.5 {
                    Text("Average weight · \(formattedWeight(average)) \(unitsSymbol)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let duration = breakdown.totalDuration {
                    Text("Total time · \(formattedDuration(duration))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(.secondarySystemBackground))
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
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color(.systemGray4), lineWidth: 0.5)
        )
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

    private var metricsRow: some View {
        let chips = metricChips()
        return Group {
            if chips.isEmpty {
                EmptyView()
            } else {
                ChipGrid(chips: chips)
            }
        }
    }

    private func metricChips() -> [String] {
        var chips: [String] = []
        if breakdown.totalSets > 0 {
            chips.append("\(breakdown.totalSets) set\(breakdown.totalSets == 1 ? "" : "s")")
        }
        if breakdown.totalReps > 0 {
            chips.append("\(breakdown.totalReps) reps")
        }
        if breakdown.volume > 0 {
            let volumeText = formattedVolume(breakdown.volume)
            chips.append("Volume \(volumeText) \(unitsSymbol)")
        }
        return chips
    }

    private func formattedWeight(_ weight: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = weight.truncatingRemainder(dividingBy: 1) == 0 ? 0 : 1
        return formatter.string(from: NSNumber(value: weight)) ?? "0"
    }

    private func formattedVolume(_ volume: Double) -> String {
        guard volume > 0 else { return "0" }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: volume)) ?? "0"
    }

    private func formattedDuration(_ duration: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = duration >= 3600 ? [.hour, .minute] : [.minute, .second]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: duration) ?? "0m"
    }
}

private struct ChipGrid: View {
    let chips: [String]

    private let columns: [GridItem] = [
        GridItem(.adaptive(minimum: 110), spacing: 8, alignment: .leading)
    ]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
            ForEach(chips, id: \.self) { chip in
                Chip(text: chip)
            }
        }
    }
}

private struct Chip: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.primary)
            .padding(.vertical, 4)
            .padding(.horizontal, 10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(.systemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color(.systemGray4), lineWidth: 0.5)
            )
    }
}
