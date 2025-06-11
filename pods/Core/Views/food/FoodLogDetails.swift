//
//  FoodLogDetails.swift
//  Pods
//
//  Created by Dimi Nunez on 5/19/25.
//

import SwiftUI

struct FoodLogDetails: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var foodManager: FoodManager
    @EnvironmentObject var dayLogsVM: DayLogsViewModel
    let log: CombinedLog
    
    // Editable state
    @State private var editedServings: Double
    @State private var editedDate: Date
    @State private var editedMealType: String
    @State private var hasChanges: Bool = false
    @State private var isUpdating: Bool = false
    @State private var showServingsPicker: Bool = false
    @State private var showDatePicker: Bool = false
    @State private var showTimePicker: Bool = false
    

    
    var food: Food {
        log.food?.asFood ?? Food(fdcId: 0, description: "Unknown", brandOwner: nil, brandName: nil, servingSize: nil, numberOfServings: nil, servingSizeUnit: nil, householdServingFullText: nil, foodNutrients: [], foodMeasures: [])
    }
    
    init(log: CombinedLog) {
        self.log = log
        self._editedServings = State(initialValue: log.food?.numberOfServings ?? 1.0)
        self._editedDate = State(initialValue: log.scheduledAt ?? Date())
        self._editedMealType = State(initialValue: log.mealType ?? "Lunch")
    }
    
    // Helper to get nutrient value by name
    private func nutrientValue(_ name: String) -> String {
        if let value = food.foodNutrients.first(where: { $0.nutrientName == name })?.value {
            return String(format: "%g", value)
        }
        return "0"
    }
    
    // Helper to get nutrient value with unit
    private func nutrientValueWithUnit(_ name: String, defaultUnit: String) -> String {
        if let nutrient = food.foodNutrients.first(where: { $0.nutrientName == name }) {
            let value = nutrient.value ?? 0
            let unit = nutrient.unitName ?? defaultUnit
            return "\(String(format: "%g", value)) \(unit)"
        }
        return "0 \(defaultUnit)"
    }
    
    @State private var showMoreNutrients: Bool = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Basic food info card
                ZStack(alignment: .top) {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color("iosnp"))
                    VStack(spacing: 0) {
                        // Title
                        HStack {
                            Text(food.displayName)
                                .foregroundColor(.primary)
                            Spacer()
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 16)
                        Divider().padding(.leading, 16)
                        // Serving Size
                        HStack {
                            Text("Serving Size")
                                .foregroundColor(.primary)
                            Spacer()
                            Text(food.householdServingFullText ?? "-")
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 16)
                        Divider().padding(.leading, 16)
                        // Number of Servings - EDITABLE
                        HStack {
                            Text("Number of Servings")
                                .foregroundColor(.primary)
                            Spacer()
                            Text(editedServings.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(editedServings))" : String(format: "%.1f", editedServings))
                                .foregroundColor(.primary)
                                .onTapGesture {
                                    showServingsPicker = true
                                }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 16)
                        Divider().padding(.leading, 16)
                        // Date - NEW EDITABLE FIELD
                        HStack {
                            Text("Date")
                                .foregroundColor(.primary)
                            Spacer()
                            HStack(spacing: 8) {
                                Button(action: {
                                    showDatePicker = true
                                }) {
                                    Text(editedDate, style: .date)
                                        .foregroundColor(.primary)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(Color("iosbtn"))
                                        .cornerRadius(8)
                                }
                                .buttonStyle(PlainButtonStyle())
                                
                                Button(action: {
                                    showTimePicker = true
                                }) {
                                    Text(editedDate, style: .time)
                                        .foregroundColor(.primary)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(Color("iosbtn"))
                                        .cornerRadius(8)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 16)
                    }
                }
                .padding(.horizontal)
                // Nutrition facts section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Nutrition Facts")
                        .font(.title2)
                        .fontWeight(.bold)
                        .padding(.horizontal)
                    ZStack(alignment: .top) {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color("iosnp"))
                        VStack(spacing: 0) {
                            // Calories
                            HStack {
                                Text("Calories")
                                Spacer()
                                Text(nutrientValue("Energy"))
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 16)
                            Divider().padding(.leading, 16)
                            // Protein
                            HStack {
                                Text("Protein (g)")
                                Spacer()
                                Text(nutrientValue("Protein"))
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 16)
                            Divider().padding(.leading, 16)
                            // Carbs
                            HStack {
                                Text("Carbs (g)")
                                Spacer()
                                Text(nutrientValue("Carbohydrate, by difference"))
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 16)
                            Divider().padding(.leading, 16)
                            // Fat
                            HStack {
                                Text("Total Fat (g)")
                                Spacer()
                                Text(nutrientValue("Total lipid (fat)"))
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 16)
                        }
                    }
                    .padding(.horizontal)
                    // Show More Nutrients button
                    Button(action: { withAnimation { showMoreNutrients.toggle() } }) {
                        HStack {
                            Text(showMoreNutrients ? "Hide Additional Nutrients" : "Show More Nutrients")
                                .foregroundColor(.accentColor)
                            Image(systemName: showMoreNutrients ? "chevron.up" : "chevron.down")
                                .foregroundColor(.accentColor)
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 14)
                        .background(Color("iosnp"))
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)
                }
                // Additional nutrients section (collapsible)
                if showMoreNutrients {
                    VStack(alignment: .leading, spacing: 16) {
                        ZStack(alignment: .top) {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color("iosnp"))
                            VStack(spacing: 0) {
                                ForEach(additionalNutrients, id: \.0) { label, name, unit in
                                    HStack {
                                        Text(label)
                                        Spacer()
                                        Text(nutrientValueWithUnit(name, defaultUnit: unit))
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(.horizontal)
                                    .padding(.vertical, 16)
                                    Divider().padding(.leading, 16)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    .transition(.opacity)
                }
                Spacer().frame(height: 40)
            }
            .padding(.top, 16)
        }
        .background(Color("iosbg"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Log Details").font(.headline)
            }
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                }
            }
            
            // Show Done button when there are changes
            if hasChanges {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: updateFoodLog) {
                        if isUpdating {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Text("Done")
                                .fontWeight(.semibold)
                        }
                    }
                    .disabled(isUpdating)
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .onChange(of: editedServings) { _ in checkForChanges() }
        .onChange(of: editedDate) { _ in checkForChanges() }
        .onChange(of: editedMealType) { _ in checkForChanges() }
        .sheet(isPresented: $showServingsPicker) {
            servingsSelectorSheet()
        }
        .sheet(isPresented: $showDatePicker) {
            NavigationView {
                VStack {
                    DatePicker("Select Date", 
                             selection: $editedDate, 
                             displayedComponents: [.date])
                        .datePickerStyle(.wheel)
                        .labelsHidden()
                    Spacer()
                }
                .padding()
                .navigationTitle("Date")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            showDatePicker = false
                        }
                    }
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancel") {
                            // Reset to original date
                            editedDate = log.scheduledAt ?? Date()
                            showDatePicker = false
                        }
                    }
                }
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showTimePicker) {
            NavigationView {
                VStack {
                    DatePicker("Select Time", 
                             selection: $editedDate, 
                             displayedComponents: [.hourAndMinute])
                        .datePickerStyle(.wheel)
                        .labelsHidden()
                    Spacer()
                }
                .padding()
                .navigationTitle("Time")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            showTimePicker = false
                        }
                    }
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancel") {
                            // Reset to original date
                            editedDate = log.scheduledAt ?? Date()
                            showTimePicker = false
                        }
                    }
                }
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
    }
    
    // Helper functions
    private func checkForChanges() {
        let originalServings = log.food?.numberOfServings ?? 1.0
        let originalDate = log.scheduledAt ?? Date()
        let originalMealType = log.mealType ?? "Lunch"
        
        hasChanges = (editedServings != originalServings) || 
                    (abs(editedDate.timeIntervalSince(originalDate)) > 60) || // More than 1 minute difference
                    (editedMealType != originalMealType)
    }
    
    private func updateFoodLog() {
        guard let foodLogId = log.foodLogId else { return }
        
        isUpdating = true
        
        // Use the new DayLogsViewModel.updateLog function
        dayLogsVM.updateLog(
            log: log,
            servings: editedServings,
            date: editedDate,
            mealType: editedMealType
        ) { result in
            isUpdating = false
            
            switch result {
            case .success:
                print("✅ Successfully updated food log")
                hasChanges = false
                dismiss()
                
            case .failure(let error):
                print("❌ Failed to update food log: \(error)")
                // Show error to user - you might want to add an alert state for this
            }
        }
    }
    
    private func servingsSelectorSheet() -> some View {
        VStack(spacing: 0) {
            // Custom Navigation Bar
            ZStack {
                // Done button on trailing edge
                HStack {
                    Spacer()
                    Button("Done") {
                        showServingsPicker = false
                    }
                }
                
                // Centered title
                Text("Servings")
                    .font(.headline)
            }
            .padding()
            
            Divider()
            
            // Centered Picker
            ServingsPickerWheel(
                selectedWhole: Binding(
                    get: { Int(editedServings) },
                    set: { newValue in
                        editedServings = Double(newValue) + editedServings.truncatingRemainder(dividingBy: 1)
                    }
                ),
                selectedFraction: Binding(
                    get: { editedServings.truncatingRemainder(dividingBy: 1) },
                    set: { newValue in
                        editedServings = Double(Int(editedServings)) + newValue
                    }
                )
            )
            .frame(height: 216)
        }
        .presentationDetents([.height(UIScreen.main.bounds.height / 3.3)])
        .presentationDragIndicator(.visible)
        .ignoresSafeArea(.all, edges: .top)
    }
    
    // List of additional nutrients to show
    private var additionalNutrients: [(String, String, String)] {
        [
            ("Saturated Fat (g)", "Saturated Fatty Acids", "g"),
            ("Polyunsaturated Fat (g)", "Polyunsaturated Fatty Acids", "g"),
            ("Monounsaturated Fat (g)", "Monounsaturated Fatty Acids", "g"),
            ("Trans Fat (g)", "Trans Fatty Acids", "g"),
            ("Cholesterol (mg)", "Cholesterol", "mg"),
            ("Sodium (mg)", "Sodium", "mg"),
            ("Potassium (mg)", "Potassium", "mg"),
            ("Sugar (g)", "Sugar", "g"),
            ("Fiber (g)", "Fiber", "g"),
            ("Vitamin A (%)", "Vitamin A", "%"),
            ("Vitamin C (%)", "Vitamin C", "%"),
            ("Calcium (%)", "Calcium", "%"),
            ("Iron (%)", "Iron", "%")
        ]
    }
}

#Preview {
    // Provide a mock Food object for preview
    let food = Food(
        fdcId: 1,
        description: "Sample Food",
        brandOwner: nil,
        brandName: nil,
        servingSize: 1.0,
        numberOfServings: 1.0,
        servingSizeUnit: "g",
        householdServingFullText: "1 cup",
        foodNutrients: [
            Nutrient(nutrientName: "Energy", value: 120, unitName: "kcal"),
            Nutrient(nutrientName: "Protein", value: 5, unitName: "g"),
            Nutrient(nutrientName: "Carbohydrate, by difference", value: 20, unitName: "g"),
            Nutrient(nutrientName: "Total lipid (fat)", value: 2, unitName: "g"),
            Nutrient(nutrientName: "Saturated Fatty Acids", value: 1, unitName: "g"),
            Nutrient(nutrientName: "Polyunsaturated Fatty Acids", value: 0.5, unitName: "g"),
            Nutrient(nutrientName: "Monounsaturated Fatty Acids", value: 0.3, unitName: "g"),
            Nutrient(nutrientName: "Trans Fatty Acids", value: 0, unitName: "g"),
            Nutrient(nutrientName: "Cholesterol", value: 10, unitName: "mg"),
            Nutrient(nutrientName: "Sodium", value: 100, unitName: "mg"),
            Nutrient(nutrientName: "Potassium", value: 200, unitName: "mg"),
            Nutrient(nutrientName: "Sugar", value: 8, unitName: "g"),
            Nutrient(nutrientName: "Fiber", value: 3, unitName: "g"),
            Nutrient(nutrientName: "Vitamin A", value: 10, unitName: "%"),
            Nutrient(nutrientName: "Vitamin C", value: 15, unitName: "%"),
            Nutrient(nutrientName: "Calcium", value: 20, unitName: "%"),
            Nutrient(nutrientName: "Iron", value: 5, unitName: "%")
        ],
        foodMeasures: []
    )
    let mockLog = CombinedLog(
        type: .food,
        status: "success",
        calories: 180, // 120 * 1.5 servings
        message: "Sample Food – Lunch",
        foodLogId: 1,
        food: LoggedFoodItem(
            fdcId: 1,
            displayName: "Sample Food",
            calories: 120,
            servingSizeText: "1 cup",
            numberOfServings: 1.5,
            brandText: "Sample Brand",
            protein: 5,
            carbs: 20,
            fat: 2
        ),
        mealType: "Lunch",
        mealLogId: nil,
        meal: nil,
        mealTime: nil,
        scheduledAt: Date(),
        recipeLogId: nil,
        recipe: nil,
        servingsConsumed: nil
    )
    
    return FoodLogDetails(log: mockLog)
        .environmentObject(FoodManager())
        .environmentObject(DayLogsViewModel())
}



struct ServingsPickerWheel: UIViewRepresentable {
    @Binding var selectedWhole: Int
    @Binding var selectedFraction: Double
    
    private let wholeNumbers = Array(1...20)
    private let fractions: [Double] = [0, 0.125, 0.25, 0.333, 0.5, 0.667, 0.75, 0.875]
    private let fractionLabels = ["-", "1/8", "1/4", "1/3", "1/2", "2/3", "3/4", "7/8"]
    
    func makeUIView(context: Context) -> UIPickerView {
        let picker = UIPickerView()
        picker.delegate = context.coordinator
        picker.dataSource = context.coordinator
        return picker
    }
    
    func updateUIView(_ uiView: UIPickerView, context: Context) {
        // Find the index of the current whole number
        if let wholeIndex = wholeNumbers.firstIndex(of: selectedWhole) {
            uiView.selectRow(wholeIndex, inComponent: 0, animated: false)
        }
        
        // Find the index of the current fraction
        if let fractionIndex = fractions.firstIndex(of: selectedFraction) {
            uiView.selectRow(fractionIndex, inComponent: 1, animated: false)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIPickerViewDataSource, UIPickerViewDelegate {
        let parent: ServingsPickerWheel
        
        init(_ parent: ServingsPickerWheel) {
            self.parent = parent
        }
        
        func numberOfComponents(in pickerView: UIPickerView) -> Int {
            return 2
        }
        
        func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
            return component == 0 ? parent.wholeNumbers.count : parent.fractions.count
        }
        
        func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
            if component == 0 {
                return "\(parent.wholeNumbers[row])"
            } else {
                return parent.fractionLabels[row]
            }
        }
        
        func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
            if component == 0 {
                parent.selectedWhole = parent.wholeNumbers[row]
            } else {
                parent.selectedFraction = parent.fractions[row]
            }
        }
    }
}
