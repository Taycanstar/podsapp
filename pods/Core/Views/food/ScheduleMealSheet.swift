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
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundColor(.primary)
                            .imageScale(.medium)
                    }
                    .accessibilityLabel("Cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        let selection = ScheduleMealSelection(
                            scheduleType: scheduleType,
                            targetDate: targetDate,
                            mealType: mealType
                        )
                        onComplete(selection)
                        dismiss()
                    } label: {
                        Image(systemName: "checkmark")
                            .foregroundColor(.accentColor)
                            .imageScale(.medium)
                    }
                    .accessibilityLabel("Save")
                }
            }
        }
    }

    private var schedulingCard: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Text("Date and Time")
                    .font(.body)
                    .foregroundColor(.primary)

                Spacer()

                if scheduleType == .once {
                    DatePicker("", selection: $targetDate, displayedComponents: .date)
                        .labelsHidden()
                        .datePickerStyle(.compact)
                }

                DatePicker("", selection: $targetDate, displayedComponents: .hourAndMinute)
                    .labelsHidden()
                    .datePickerStyle(.compact)
            }
            .padding(.vertical, 2)

            Divider()

            HStack {
                Text("Meal Type")
                    .font(.body)
                    .foregroundColor(.primary)

                Spacer()

                Picker("Meal Type", selection: $mealType) {
                    ForEach(mealTypeOptions, id: \.self) { option in
                        Text(option)
                            .foregroundColor(.primary)
                            .tag(option)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
            }
            .padding(.vertical, 2)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color("containerbg"))
        .cornerRadius(20)
    }
}
