//
//  FlexibleExerciseInputs.swift
//  pods
//
//  Created by Claude on 8/28/25.
//

import SwiftUI
import Foundation

// MARK: - Dynamic Set Row View

/// Dynamic set row that adapts its input interface based on the exercise tracking type
/// Uses legacy visual style with simple List/HStack layout
struct DynamicSetRowView: View {
    @Binding var set: FlexibleSetData
    let setNumber: Int
    let workoutExercise: TodayWorkoutExercise
    let onDurationChanged: ((TimeInterval) -> Void)?
    let isActive: Bool // Whether this set is currently active
    let onFocusChanged: ((Bool) -> Void)? // Callback when this row gains/loses focus
    let onSetChanged: (() -> Void)? // Callback when set data changes
    let onPickerStateChanged: ((Bool) -> Void)? // Callback when time picker state changes
    @FocusState private var focusedField: FocusedField?

    @State private var showTimePicker: Bool = false
    
    enum FocusedField: Hashable {
        case firstInput, secondInput
    }
    
    var body: some View {
        // Dynamic input based on tracking type (using legacy TextField style)
        dynamicInputView
            .listRowInsets(EdgeInsets())
            .listRowSeparator(.hidden)
            .padding(.vertical, 6)
            .padding(.horizontal, 2) // Extra padding for border rendering
            .contentShape(Rectangle()) // Prevent shape clipping
            .onChange(of: focusedField) { oldValue, newValue in
                // When any field in this row gains focus, make this row the active set
                onFocusChanged?(newValue != nil)
                
                // Add haptic feedback when field gains focus
                if oldValue == nil && newValue != nil {
                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                    impactFeedback.impactOccurred()
                }
            }
            .onChange(of: showTimePicker) { _, newValue in
                // Notify parent when time picker state changes for dynamic height
                onPickerStateChanged?(newValue)
            }
    }
    
    private var setNumberIndicator: some View {
        ZStack {
            // Background rounded rectangle (matches input style)
            RoundedRectangle(cornerRadius: 16)
                .fill(set.isCompleted ? Color.accentColor : Color("containerbg"))
                .strokeBorder(
                    set.isCompleted ? Color.accentColor : Color(.systemGray4), 
                    lineWidth: set.isCompleted ? 0 : 0.5
                )
                .frame(width: 44, height: 44)
            
            // Content (number or checkmark)
            if set.isCompleted {
                Image(systemName: "checkmark")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            } else {
                Text("\(setNumber)")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(.primary)
            }
        }
    }
    
    @ViewBuilder
    private var dynamicInputView: some View {
        switch set.trackingType {
        case .repsWeight:
            repsWeightInput
        case .timeDistance:
            durationDistanceInput
        case .timeOnly:
            durationOnlyInput // Duration-only exercises
        // Handle legacy types that might still exist in saved data
        case .repsOnly:
            repsWeightInput // Treat as reps+weight
        case .holdTime:
            durationOnlyInput // Treat as duration-only
        case .rounds:
            durationOnlyInput // Treat as duration-only
        }
    }
    
    // MARK: - Exercise Input Views
    
    private var repsWeightInput: some View {
        HStack(spacing: 16) {
            // Set indicator for reps-based exercises
            setNumberIndicator
            
            TextField("\(workoutExercise.reps)", text: Binding(
                get: { set.reps ?? "" },
                set: { 
                    set.reps = $0
                    onSetChanged?()
                }
            ))
            .focused($focusedField, equals: .firstInput)
            .textFieldStyle(CustomTextFieldStyleWorkout(isFocused: focusedField == .firstInput, unit: "reps", isActive: isActive))
            .keyboardType(.numberPad)
            .submitLabel(.next)
            .onSubmit {
                focusedField = .secondInput
            }
            
            // Only show weight field for reps+weight exercises
            if set.trackingType == .repsWeight {
                TextField((workoutExercise.weight ?? 0) > 0 ? "\(Int(workoutExercise.weight ?? 0))" : "150", text: Binding(
                    get: { set.weight ?? "" },
                    set: { 
                        set.weight = $0
                        onSetChanged?()
                    }
                ))
                .focused($focusedField, equals: .secondInput)
                .textFieldStyle(CustomTextFieldStyleWorkout(isFocused: focusedField == .secondInput, unit: "lbs", isActive: isActive))
                .keyboardType(.decimalPad)
                .submitLabel(.done)
                .onTapGesture {
                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                    impactFeedback.impactOccurred()
                }
                .onSubmit {
                    focusedField = nil
                }
            }
        }
    }
    
    private var repsOnlyInput: some View {
        HStack(spacing: 16) {
            // Set indicator for reps-based exercises
            setNumberIndicator
            
            TextField("\(workoutExercise.reps)", text: Binding(
                get: { set.reps ?? "" },
                set: { 
                    set.reps = $0
                    onSetChanged?()
                }
            ))
            .focused($focusedField, equals: .firstInput)
            .textFieldStyle(CustomTextFieldStyleWorkout(isFocused: focusedField == .firstInput, unit: "reps", isActive: isActive))
            .keyboardType(.numberPad)
            .submitLabel(.done)
            .onSubmit {
                focusedField = nil
            }
        }
    }
    
    private var durationDistanceInput: some View {
        VStack(spacing: 4) {
            // Duration and distance input row with set indicator aligned
            VStack(spacing: 8) {
                HStack(spacing: 16) {
                    // Set indicator aligned with duration input
                    setNumberIndicator
                    
                    // Duration input button
                    Button(action: {
                        // Clear text field focus first to avoid conflicts
                        focusedField = nil
                        
                        // Add small delay to ensure focus is cleared before showing picker
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            showTimePicker.toggle()
                        }
                    }) {
                        HStack {
                            Text(formatTimeInput(set.duration ?? 0))
                                .foregroundColor(showTimePicker ? .blue : .primary)
                                .font(.system(size: 16, weight: .medium))
                            
                            Spacer()
                            
                            if showTimePicker {
                                Text("Duration")
                                    .font(.system(size: 14))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color("containerbg"))
                                .strokeBorder(Color(.systemGray4), lineWidth: 0.5)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    // Only show distance field for time+distance exercises
                    if set.trackingType == .timeDistance {
                        // Distance input horizontally aligned with duration
                        TextField("Distance", text: Binding(
                            get: { 
                                if let distance = set.distance {
                                    return "\(Int(distance))"
                                }
                                return ""
                            },
                            set: { value in
                                if let distance = Double(value) {
                                    set.distance = distance
                                    set.distanceUnit = .miles
                                }
                                onSetChanged?()
                            }
                        ))
                        .focused($focusedField, equals: .secondInput)
                        .textFieldStyle(CustomTextFieldStyleWorkout(isFocused: focusedField == .secondInput, unit: "mi", isActive: isActive))
                        .keyboardType(.decimalPad)
                        .submitLabel(.done)
                        .onSubmit {
                            focusedField = nil
                        }
                    }
                }
                
                // iOS native inline time picker for duration
                if showTimePicker {
                    HStack(spacing: 0) {
                        // Hours
                        Picker("Hours", selection: Binding(
                            get: { Int((set.duration ?? 0) / 3600) },
                            set: { newHours in
                                let currentMinutes = Int(((set.duration ?? 0).truncatingRemainder(dividingBy: 3600)) / 60)
                                let currentSeconds = Int((set.duration ?? 0).truncatingRemainder(dividingBy: 60))
                                let newDuration = TimeInterval(newHours * 3600 + currentMinutes * 60 + currentSeconds)
                                set.duration = newDuration
                                onDurationChanged?(newDuration)
                                onSetChanged?()
                            }
                        )) {
                            ForEach(0...23, id: \.self) { hour in
                                Text("\(hour) hr").tag(hour)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(maxWidth: .infinity)
                        
                        // Minutes
                        Picker("Minutes", selection: Binding(
                            get: { Int(((set.duration ?? 0).truncatingRemainder(dividingBy: 3600)) / 60) },
                            set: { newMinutes in
                                let currentHours = Int((set.duration ?? 0) / 3600)
                                let currentSeconds = Int((set.duration ?? 0).truncatingRemainder(dividingBy: 60))
                                let newDuration = TimeInterval(currentHours * 3600 + newMinutes * 60 + currentSeconds)
                                set.duration = newDuration
                                onDurationChanged?(newDuration)
                                onSetChanged?()
                            }
                        )) {
                            ForEach(0...59, id: \.self) { minute in
                                Text("\(minute) min").tag(minute)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(maxWidth: .infinity)
                        
                        // Seconds
                        Picker("Seconds", selection: Binding(
                            get: { Int((set.duration ?? 0).truncatingRemainder(dividingBy: 60)) },
                            set: { newSeconds in
                                let currentHours = Int((set.duration ?? 0) / 3600)
                                let currentMinutes = Int(((set.duration ?? 0).truncatingRemainder(dividingBy: 3600)) / 60)
                                let newDuration = TimeInterval(currentHours * 3600 + currentMinutes * 60 + newSeconds)
                                set.duration = newDuration
                                onDurationChanged?(newDuration)
                                onSetChanged?()
                            }
                        )) {
                            ForEach(0...59, id: \.self) { second in
                                Text("\(second) sec").tag(second)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(maxWidth: .infinity)
                    }
                    .frame(height: 180)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
    }
    
    private var durationOnlyInput: some View {
        VStack(spacing: 0) {
            // Duration input row with set indicator aligned
            VStack(spacing: 0) {
                HStack(spacing: 16) {
                    // Set indicator aligned with duration input
                    setNumberIndicator
                    
                    // Duration input button
                    Button(action: {
                        // Clear text field focus first to avoid conflicts
                        focusedField = nil
                        
                        // Add small delay to ensure focus is cleared before showing picker
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            showTimePicker.toggle()
                        }
                    }) {
                        HStack {
                            Text(formatTimeInput(set.duration ?? 0))
                                .foregroundColor(showTimePicker ? .blue : .primary)
                                .font(.system(size: 16, weight: .medium))
                            
                            Spacer()
                            
                            if showTimePicker {
                                Text("Duration")
                                    .font(.system(size: 14))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color("containerbg"))
                                .strokeBorder(Color(.systemGray4), lineWidth: 0.5)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                // iOS native inline time picker for duration
                if showTimePicker {
                    HStack(spacing: 0) {
                        // Hours
                        Picker("Hours", selection: Binding(
                            get: { Int((set.duration ?? 0) / 3600) },
                            set: { newHours in
                                let currentMinutes = Int(((set.duration ?? 0).truncatingRemainder(dividingBy: 3600)) / 60)
                                let currentSeconds = Int((set.duration ?? 0).truncatingRemainder(dividingBy: 60))
                                let newDuration = TimeInterval(newHours * 3600 + currentMinutes * 60 + currentSeconds)
                                set.duration = newDuration
                                onDurationChanged?(newDuration)
                                onSetChanged?()
                            }
                        )) {
                            ForEach(0...23, id: \.self) { hour in
                                Text("\(hour) hr").tag(hour)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(maxWidth: .infinity)
                        
                        // Minutes
                        Picker("Minutes", selection: Binding(
                            get: { Int(((set.duration ?? 0).truncatingRemainder(dividingBy: 3600)) / 60) },
                            set: { newMinutes in
                                let currentHours = Int((set.duration ?? 0) / 3600)
                                let currentSeconds = Int((set.duration ?? 0).truncatingRemainder(dividingBy: 60))
                                let newDuration = TimeInterval(currentHours * 3600 + newMinutes * 60 + currentSeconds)
                                set.duration = newDuration
                                onDurationChanged?(newDuration)
                                onSetChanged?()
                            }
                        )) {
                            ForEach(0...59, id: \.self) { minute in
                                Text("\(minute) min").tag(minute)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(maxWidth: .infinity)
                        
                        // Seconds
                        Picker("Seconds", selection: Binding(
                            get: { Int((set.duration ?? 0).truncatingRemainder(dividingBy: 60)) },
                            set: { newSeconds in
                                let currentHours = Int((set.duration ?? 0) / 3600)
                                let currentMinutes = Int(((set.duration ?? 0).truncatingRemainder(dividingBy: 3600)) / 60)
                                let newDuration = TimeInterval(currentHours * 3600 + currentMinutes * 60 + newSeconds)
                                set.duration = newDuration
                                onDurationChanged?(newDuration)
                                onSetChanged?()
                            }
                        )) {
                            ForEach(0...59, id: \.self) { second in
                                Text("\(second) sec").tag(second)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(maxWidth: .infinity)
                    }
                    .frame(height: 180)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
    }
    
    private var holdTimeInput: some View {
        VStack(spacing: 4) {
            // Duration input row with set indicator aligned
            VStack(spacing: 8) {
                HStack(spacing: 16) {
                    // Set indicator aligned with duration input
                    setNumberIndicator
                    
                    // Duration input button
                    Button(action: {
                        // Clear text field focus first to avoid conflicts
                        focusedField = nil
                        
                        // Add small delay to ensure focus is cleared before showing picker
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            showTimePicker.toggle()
                        }
                    }) {
                        HStack {
                            Text(formatTimeInput(set.duration ?? 0))
                                .foregroundColor(showTimePicker ? .blue : .primary)
                                .font(.system(size: 16, weight: .medium))
                            
                            Spacer()
                            
                            if showTimePicker {
                                Text("Duration")
                                    .font(.system(size: 14))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color("containerbg"))
                                .strokeBorder(Color(.systemGray4), lineWidth: 0.5)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                // iOS native inline time picker for duration
                if showTimePicker {
                    HStack(spacing: 0) {
                        // Hours
                        Picker("Hours", selection: Binding(
                            get: { Int((set.duration ?? 0) / 3600) },
                            set: { newHours in
                                let currentMinutes = Int(((set.duration ?? 0).truncatingRemainder(dividingBy: 3600)) / 60)
                                let currentSeconds = Int((set.duration ?? 0).truncatingRemainder(dividingBy: 60))
                                let newDuration = TimeInterval(newHours * 3600 + currentMinutes * 60 + currentSeconds)
                                set.duration = newDuration
                                onDurationChanged?(newDuration)
                                onSetChanged?()
                            }
                        )) {
                            ForEach(0...23, id: \.self) { hour in
                                Text("\(hour) hr").tag(hour)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(maxWidth: .infinity)
                        
                        // Minutes
                        Picker("Minutes", selection: Binding(
                            get: { Int(((set.duration ?? 0).truncatingRemainder(dividingBy: 3600)) / 60) },
                            set: { newMinutes in
                                let currentHours = Int((set.duration ?? 0) / 3600)
                                let currentSeconds = Int((set.duration ?? 0).truncatingRemainder(dividingBy: 60))
                                let newDuration = TimeInterval(currentHours * 3600 + newMinutes * 60 + currentSeconds)
                                set.duration = newDuration
                                onDurationChanged?(newDuration)
                                onSetChanged?()
                            }
                        )) {
                            ForEach(0...59, id: \.self) { minute in
                                Text("\(minute) min").tag(minute)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(maxWidth: .infinity)
                        
                        // Seconds
                        Picker("Seconds", selection: Binding(
                            get: { Int((set.duration ?? 0).truncatingRemainder(dividingBy: 60)) },
                            set: { newSeconds in
                                let currentHours = Int((set.duration ?? 0) / 3600)
                                let currentMinutes = Int(((set.duration ?? 0).truncatingRemainder(dividingBy: 3600)) / 60)
                                let newDuration = TimeInterval(currentHours * 3600 + currentMinutes * 60 + newSeconds)
                                set.duration = newDuration
                                onDurationChanged?(newDuration)
                                onSetChanged?()
                            }
                        )) {
                            ForEach(0...59, id: \.self) { second in
                                Text("\(second) sec").tag(second)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(maxWidth: .infinity)
                    }
                    .frame(height: 180)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            
            
            // Weight input row (no set indicator)
            TextField((workoutExercise.weight ?? 0) > 0 ? "\(Int(workoutExercise.weight ?? 0))" : "150", text: Binding(
                get: { set.weight ?? "" },
                set: { 
                    set.weight = $0
                    onSetChanged?()
                }
            ))
            .focused($focusedField, equals: .secondInput)
            .textFieldStyle(CustomTextFieldStyleWorkout(isFocused: focusedField == .secondInput, unit: "lbs"))
            .keyboardType(.decimalPad)
            .submitLabel(.done)
            .onSubmit {
                focusedField = nil
            }
        }
    }
    
    private var roundsInput: some View {
        VStack(spacing: 4) {
            // Rounds input row
            TextField("5", text: Binding(
                get: { 
                    if let rounds = set.rounds {
                        return "\(rounds)"
                    }
                    return ""
                },
                set: { newValue in
                    set.rounds = Int(newValue)
                    onSetChanged?()
                }
            ))
            .focused($focusedField, equals: .firstInput)
            .textFieldStyle(CustomTextFieldStyleWorkout(isFocused: focusedField == .firstInput, unit: "rounds", isActive: isActive))
            .keyboardType(.numberPad)
            .submitLabel(.done)
            .onSubmit {
                focusedField = nil
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    showTimePicker = true
                }
            }
            
            // Duration input - full width row
            VStack(spacing: 8) {
                Button(action: {
                    showTimePicker.toggle()
                    if showTimePicker {
                        focusedField = nil // Clear any text field focus
                    }
                }) {
                    HStack {
                        Text(formatTimeInput(set.duration ?? 0))
                            .foregroundColor(.primary)
                            .font(.system(size: 16, weight: .medium))
                        
                        Spacer()
                        
                        if showTimePicker {
                            Text("each")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color("containerbg"))
                            .strokeBorder(Color(.systemGray4), lineWidth: 0.5)
                    )
                }
                .buttonStyle(PlainButtonStyle())
                
                // iOS native inline time picker for duration
                if showTimePicker {
                    HStack(spacing: 0) {
                        // Hours
                        Picker("Hours", selection: Binding(
                            get: { Int((set.duration ?? 0) / 3600) },
                            set: { newHours in
                                let currentMinutes = Int(((set.duration ?? 0).truncatingRemainder(dividingBy: 3600)) / 60)
                                let currentSeconds = Int((set.duration ?? 0).truncatingRemainder(dividingBy: 60))
                                let newDuration = TimeInterval(newHours * 3600 + currentMinutes * 60 + currentSeconds)
                                set.duration = newDuration
                                onDurationChanged?(newDuration)
                                onSetChanged?()
                            }
                        )) {
                            ForEach(0...23, id: \.self) { hour in
                                Text("\(hour) hr").tag(hour)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(maxWidth: .infinity)
                        
                        // Minutes
                        Picker("Minutes", selection: Binding(
                            get: { Int(((set.duration ?? 0).truncatingRemainder(dividingBy: 3600)) / 60) },
                            set: { newMinutes in
                                let currentHours = Int((set.duration ?? 0) / 3600)
                                let currentSeconds = Int((set.duration ?? 0).truncatingRemainder(dividingBy: 60))
                                let newDuration = TimeInterval(currentHours * 3600 + newMinutes * 60 + currentSeconds)
                                set.duration = newDuration
                                onDurationChanged?(newDuration)
                                onSetChanged?()
                            }
                        )) {
                            ForEach(0...59, id: \.self) { minute in
                                Text("\(minute) min").tag(minute)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(maxWidth: .infinity)
                        
                        // Seconds
                        Picker("Seconds", selection: Binding(
                            get: { Int((set.duration ?? 0).truncatingRemainder(dividingBy: 60)) },
                            set: { newSeconds in
                                let currentHours = Int((set.duration ?? 0) / 3600)
                                let currentMinutes = Int(((set.duration ?? 0).truncatingRemainder(dividingBy: 3600)) / 60)
                                let newDuration = TimeInterval(currentHours * 3600 + currentMinutes * 60 + newSeconds)
                                set.duration = newDuration
                                onDurationChanged?(newDuration)
                                onSetChanged?()
                            }
                        )) {
                            ForEach(0...59, id: \.self) { second in
                                Text("\(second) sec").tag(second)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(maxWidth: .infinity)
                    }
                    .frame(height: 180)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
    }
    
    // MARK: - Native Time Picker
    
    private var nativeTimePicker: some View {
        HStack(spacing: 8) {
            // Hours picker
            HStack(spacing: 4) {
                Picker("Hours", selection: Binding(
                    get: { Int((set.duration ?? 0) / 3600) },
                    set: { newHours in
                        let currentMinutes = Int(((set.duration ?? 0).truncatingRemainder(dividingBy: 3600)) / 60)
                        let currentSeconds = Int((set.duration ?? 0).truncatingRemainder(dividingBy: 60))
                        set.duration = TimeInterval(newHours * 3600 + currentMinutes * 60 + currentSeconds)
                    }
                )) {
                    ForEach(0...23, id: \.self) { hour in
                        Text("\(hour)").tag(hour)
                    }
                }
                .pickerStyle(.wheel)
                .frame(width: 60, height: 120)
                .clipped()
                
                Text("hr")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            
            // Minutes picker
            HStack(spacing: 4) {
                Picker("Minutes", selection: Binding(
                    get: { Int(((set.duration ?? 0).truncatingRemainder(dividingBy: 3600)) / 60) },
                    set: { newMinutes in
                        let currentHours = Int((set.duration ?? 0) / 3600)
                        let currentSeconds = Int((set.duration ?? 0).truncatingRemainder(dividingBy: 60))
                        set.duration = TimeInterval(currentHours * 3600 + newMinutes * 60 + currentSeconds)
                    }
                )) {
                    ForEach(0...59, id: \.self) { minute in
                        Text("\(minute)").tag(minute)
                    }
                }
                .pickerStyle(.wheel)
                .frame(width: 60, height: 120)
                .clipped()
                
                Text("min")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            
            // Seconds picker
            HStack(spacing: 4) {
                Picker("Seconds", selection: Binding(
                    get: { Int((set.duration ?? 0).truncatingRemainder(dividingBy: 60)) },
                    set: { newSeconds in
                        let currentHours = Int((set.duration ?? 0) / 3600)
                        let currentMinutes = Int(((set.duration ?? 0).truncatingRemainder(dividingBy: 3600)) / 60)
                        set.duration = TimeInterval(currentHours * 3600 + currentMinutes * 60 + newSeconds)
                    }
                )) {
                    ForEach(0...59, id: \.self) { second in
                        Text("\(second)").tag(second)
                    }
                }
                .pickerStyle(.wheel)
                .frame(width: 60, height: 120)
                .clipped()
                
                Text("sec")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color("containerbg"))
                .strokeBorder(Color(.systemGray4), lineWidth: 0.5)
        )
    }
    
    // MARK: - Helper Functions
    
    private func formatDuration(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        let remainingSeconds = Int(seconds) % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
    
    private func parseDuration(_ timeString: String) -> TimeInterval {
        let components = timeString.split(separator: ":")
        guard components.count == 2,
              let minutes = Int(components[0]),
              let seconds = Int(components[1]) else {
            return 0
        }
        return TimeInterval(minutes * 60 + seconds)
    }
    
    // MARK: - Time Input Formatting
    
    private func formatTimeInput(_ seconds: TimeInterval) -> String {
        let totalSeconds = Int(seconds)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let secs = totalSeconds % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%d:%02d", minutes, secs)
        }
    }
    
    private func parseTimeInput(_ timeString: String) -> TimeInterval {
        // Remove all non-digit characters to get just the numbers
        let digitsOnly = timeString.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
        
        // If empty, return 0
        guard !digitsOnly.isEmpty else { return 0 }
        
        // Take only the last 6 digits to prevent overflow, and pad to ensure we have enough digits
        let trimmedDigits = String(digitsOnly.suffix(6))
        let digitCount = trimmedDigits.count
        
        // Parse based on number of digits - treat as right-aligned entry
        if digitCount == 1 {
            // 1 digit: 5 -> 0:05 (5 seconds)
            let seconds = Int(trimmedDigits) ?? 0
            return TimeInterval(seconds)
        } else if digitCount == 2 {
            // 2 digits: 55 -> 0:55 (55 seconds)
            let seconds = Int(trimmedDigits) ?? 0
            return TimeInterval(seconds)
        } else if digitCount == 3 {
            // 3 digits: 555 -> 5:55 (5 minutes 55 seconds)
            let minutes = Int(String(trimmedDigits.prefix(1))) ?? 0
            let seconds = Int(String(trimmedDigits.suffix(2))) ?? 0
            return TimeInterval(minutes * 60 + seconds)
        } else if digitCount == 4 {
            // 4 digits: 5555 -> 55:55 (55 minutes 55 seconds)
            let minutes = Int(String(trimmedDigits.prefix(2))) ?? 0
            let seconds = Int(String(trimmedDigits.suffix(2))) ?? 0
            return TimeInterval(minutes * 60 + seconds)
        } else if digitCount == 5 {
            // 5 digits: 55555 -> 5:55:55 (5 hours 55 minutes 55 seconds)
            let hours = Int(String(trimmedDigits.prefix(1))) ?? 0
            let minutes = Int(String(trimmedDigits.dropFirst().prefix(2))) ?? 0
            let seconds = Int(String(trimmedDigits.suffix(2))) ?? 0
            return TimeInterval(hours * 3600 + minutes * 60 + seconds)
        } else {
            // 6 digits: 555555 -> 55:55:55 (55 hours 55 minutes 55 seconds)
            let hours = Int(String(trimmedDigits.prefix(2))) ?? 0
            let minutes = Int(String(trimmedDigits.dropFirst(2).prefix(2))) ?? 0
            let seconds = Int(String(trimmedDigits.suffix(2))) ?? 0
            return TimeInterval(hours * 3600 + minutes * 60 + seconds)
        }
    }
}

// MARK: - Custom TextField Style

struct CustomTextFieldStyleWorkout: TextFieldStyle {
    let isFocused: Bool
    let unit: String?
    let isActive: Bool // Whether the parent set is active
    
    init(isFocused: Bool, unit: String? = nil, isActive: Bool = false) {
        self.isFocused = isFocused
        self.unit = unit
        self.isActive = isActive
    }
    
    func _body(configuration: TextField<Self._Label>) -> some View {

        
        HStack(spacing: 0) {
            configuration
                .foregroundColor(.primary)
                .font(.system(size: 16, weight: .medium))
            
            if isFocused, let unit = unit {
                Text(unit)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color("containerbg"))
                .strokeBorder(Color(.systemGray4), lineWidth: 0.5)
        )
    }
}


