//
//  FlexibilityPickerView.swift
//  Pods
//
//  Created by Claude on 8/24/25.
//

import SwiftUI

struct FlexibilityPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var warmUpEnabled: Bool
    @Binding var coolDownEnabled: Bool
    let onSetDefault: (Bool, Bool) -> Void
    let onSetForWorkout: (Bool, Bool) -> Void
    
    @State private var tempWarmUpEnabled: Bool
    @State private var tempCoolDownEnabled: Bool
    
    init(warmUpEnabled: Binding<Bool>, coolDownEnabled: Binding<Bool>, onSetDefault: @escaping (Bool, Bool) -> Void, onSetForWorkout: @escaping (Bool, Bool) -> Void) {
        self._warmUpEnabled = warmUpEnabled
        self._coolDownEnabled = coolDownEnabled
        self.onSetDefault = onSetDefault
        self.onSetForWorkout = onSetForWorkout
        
        // Use the current values as initial values
        self._tempWarmUpEnabled = State(initialValue: warmUpEnabled.wrappedValue)
        self._tempCoolDownEnabled = State(initialValue: coolDownEnabled.wrappedValue)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with close button
            HStack {
                Spacer()
                
                Button(action: {
                    dismiss()
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                        .frame(width: 30, height: 30)
                }
            }
            .padding(.horizontal)
            .padding(.top, 16)
            .padding(.bottom, 16)
            
            Text("Flexibility")
                .font(.title2)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                .padding(.bottom, 30)
            
            // Flexibility Options List
            VStack(spacing: 16) {
                VStack(spacing: 0) {
                    // Warm-Up Toggle Row
                    Button(action: {
                        tempWarmUpEnabled.toggle()
                    }) {
                        HStack(spacing: 16) {
                            Image(systemName: "thermometer.sun")
                                .font(.system(size: 20))
                                .foregroundColor(.orange)
                                .frame(width: 24)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Warm-Up")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.primary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                
                                Text("Dynamic stretches & movement prep")
                                    .font(.system(size: 14))
                                    .foregroundColor(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            
                            Spacer()
                            
                            // Toggle Switch
                            Toggle("", isOn: $tempWarmUpEnabled)
                                .labelsHidden()
                                .tint(.orange)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 12)
                        .background(Color(.systemBackground))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Divider()
                        .padding(.leading)
                    
                    // Cool-Down Toggle Row
                    Button(action: {
                        tempCoolDownEnabled.toggle()
                    }) {
                        HStack(spacing: 16) {
                            Image(systemName: "moon.zzz")
                                .font(.system(size: 20))
                                .foregroundColor(.mint)
                                .frame(width: 24)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Cool-Down")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.primary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                
                                Text("Static stretches & recovery")
                                    .font(.system(size: 14))
                                    .foregroundColor(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            
                            Spacer()
                            
                            // Toggle Switch
                            Toggle("", isOn: $tempCoolDownEnabled)
                                .labelsHidden()
                                .tint(.mint)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 12)
                        .background(Color(.systemBackground))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                Spacer()
                
                // Action buttons
                actionButtons
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 30)
        }
        .padding(.horizontal, 10)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .presentationDetents([.fraction(0.4)])
        .presentationDragIndicator(.visible)
    }
    
    private var actionButtons: some View {
        HStack(spacing: 0) {
            Button("Set as default") {
                warmUpEnabled = tempWarmUpEnabled
                coolDownEnabled = tempCoolDownEnabled
                onSetDefault(tempWarmUpEnabled, tempCoolDownEnabled)
            }
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(Color.primary)
            .cornerRadius(8)
            
            Rectangle()
                .frame(width: 16)
                .foregroundColor(.clear)
            
            Button("Set for this workout") {
                warmUpEnabled = tempWarmUpEnabled
                coolDownEnabled = tempCoolDownEnabled
                onSetForWorkout(tempWarmUpEnabled, tempCoolDownEnabled)
            }
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(.primary)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.primary, lineWidth: 1)
            )
        }
        .padding(.top, 24)
    }
}

#Preview {
    FlexibilityPickerView(
        warmUpEnabled: .constant(true),
        coolDownEnabled: .constant(false),
        onSetDefault: { warmUp, coolDown in
            print("Set as default: Warm-Up \(warmUp), Cool-Down \(coolDown)")
        },
        onSetForWorkout: { warmUp, coolDown in
            print("Set for workout: Warm-Up \(warmUp), Cool-Down \(coolDown)")
        }
    )
}