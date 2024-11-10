//
//  DatePickerWheel.swift
//  pods
//
//  Created by Dimi Nunez on 11/10/24.
//
import SwiftUI
import Foundation

struct DatePickerWheel: View {
    @Binding var selectedDate: Date
    
    var body: some View {
        HStack {
            // Date picker
            Picker("Date", selection: Binding(
                get: { Calendar.current.startOfDay(for: selectedDate) },
                set: { newDate in
                    let components = Calendar.current.dateComponents([.hour, .minute], from: selectedDate)
                    selectedDate = Calendar.current.date(bySettingHour: components.hour ?? 0, minute: components.minute ?? 0, second: 0, of: newDate) ?? newDate
                }
            )) {
                ForEach(-7...7, id: \.self) { dayOffset in
                    if let date = Calendar.current.date(byAdding: .day, value: dayOffset, to: Date()) {
                        Text(formatPickerDate(date)).tag(Calendar.current.startOfDay(for: date))
                    }
                }
            }
            .pickerStyle(.wheel)
            
            // Hour picker
            Picker("Hour", selection: Binding(
                get: { Calendar.current.component(.hour, from: selectedDate) },
                set: { newHour in
                    selectedDate = Calendar.current.date(bySettingHour: newHour, minute: Calendar.current.component(.minute, from: selectedDate), second: 0, of: selectedDate) ?? selectedDate
                }
            )) {
                ForEach(0..<24) { hour in
                    Text("\(hour)").tag(hour)
                }
            }
            .pickerStyle(.wheel)
            
            // Minute picker
            Picker("Minute", selection: Binding(
                get: { Calendar.current.component(.minute, from: selectedDate) },
                set: { newMinute in
                    selectedDate = Calendar.current.date(bySettingHour: Calendar.current.component(.hour, from: selectedDate), minute: newMinute, second: 0, of: selectedDate) ?? selectedDate
                }
            )) {
                ForEach(0..<60) { minute in
                    Text(String(format: "%02d", minute)).tag(minute)
                }
            }
            .pickerStyle(.wheel)
        }
    }
    
    private func formatPickerDate(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            return date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
        }
    }
}
