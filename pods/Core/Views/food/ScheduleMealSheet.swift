import SwiftUI

struct ScheduleMealSelection {
    enum ScheduleType: String, CaseIterable, Identifiable {
        case once
        case daily
        
        var id: String { rawValue }
        
        var displayName: String {
            switch self {
            case .once: return "Specific Date"
            case .daily: return "Every Day"
            }
        }
    }
    
    let scheduleType: ScheduleType
    let targetDate: Date
    let mealType: String?
}

struct ScheduleMealSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var scheduleType: ScheduleMealSelection.ScheduleType = .once
    @State private var targetDate = Date()
    @State private var mealType: String
    let onComplete: (ScheduleMealSelection) -> Void

    private let mealTypeOptions = ["Breakfast", "Lunch", "Dinner", "Snack"]

    init(initialMealType: String, onComplete: @escaping (ScheduleMealSelection) -> Void) {
        _mealType = State(initialValue: initialMealType)
        self.onComplete = onComplete
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Picker("Frequency", selection: $scheduleType) {
                    ForEach(ScheduleMealSelection.ScheduleType.allCases) { type in
                        Text(type.displayName).tag(type)
                    }
                }
                .pickerStyle(.segmented)

                schedulingCard

                Spacer(minLength: 0)
            }
            .padding(.horizontal)
            .padding(.top, 24)
            .padding(.bottom, 16)
            .navigationTitle("Schedule Meal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let selection = ScheduleMealSelection(
                            scheduleType: scheduleType,
                            targetDate: targetDate,
                            mealType: mealType
                        )
                        onComplete(selection)
                        dismiss()
                    }
                }
            }
        }
    }

    private var schedulingCard: some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                Text("Date & Time")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Spacer()

                DatePicker("", selection: $targetDate, displayedComponents: .date)
                    .labelsHidden()
                    .datePickerStyle(.compact)
                    .disabled(scheduleType == .daily)
                    .opacity(scheduleType == .daily ? 0.5 : 1)

                DatePicker("", selection: $targetDate, displayedComponents: .hourAndMinute)
                    .labelsHidden()
                    .datePickerStyle(.compact)
            }

            Divider()

            HStack {
                Text("Meal Time")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Spacer()

                Picker("Meal Time", selection: $mealType) {
                    ForEach(mealTypeOptions, id: \.self) { option in
                        Text(option).tag(option)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color("containerbg"))
        .cornerRadius(20)
    }
}
