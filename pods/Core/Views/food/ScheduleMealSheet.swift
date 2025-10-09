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
            Form {
                Section(header: Text("Schedule")) {
                    Picker("Frequency", selection: $scheduleType) {
                        ForEach(ScheduleMealSelection.ScheduleType.allCases) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                    
                    DatePicker("Date", selection: $targetDate, displayedComponents: .date)
                        .disabled(scheduleType == .daily)
                        .opacity(scheduleType == .daily ? 0.5 : 1)
                }
                
                Section(header: Text("Meal")) {
                    Picker("Meal Type", selection: $mealType) {
                        ForEach(mealTypeOptions, id: \.self) { option in
                            Text(option).tag(option)
                        }
                    }
                }
            }
            .navigationTitle("Schedule Meal")
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
}
