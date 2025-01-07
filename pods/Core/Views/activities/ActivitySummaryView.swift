//
//  ActivitySummaryView.swift
//  Pods
//
//  Created by Dimi Nunez on 1/1/25.
//

import SwiftUI
import CoreLocation

struct ActivitySummaryView: View {
    let pod: Pod
    let duration: Int
    let items: [PodItem]
    let startTime: Date
    let endTime: Date
    let podColumns: [PodColumn]
    let navigationAction: (NavigationDestination) -> Void
    
    @State private var cityName: String = "Loading..."
    @Environment(\.dismiss) private var dismiss
    
    private func formatDuration(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let secs = seconds % 60
        return String(format: "%d:%02d:%02d", hours, minutes, secs)
    }
    
    private func getLoggedItemsCount() -> Int {
        return items.filter { item in
            guard let columnValues = item.columnValues else { return false }
            // Check if any column value is non-null and non-empty
            return columnValues.values.contains { value in
                switch value {
                case .null:
                    return false
                case .string(let str):
                    return !str.isEmpty
                case .number:
                    return true
                case .time(let timeValue):
                    return timeValue != TimeValue(hours: 0, minutes: 0, seconds: 0)
                case .array(let values):
                    return values.contains { val in
                        if case .null = val { return false }
                        return true
                    }
                }
            }
        }.count
    }
    
    private func formatTimeRange(_ start: Date, _ end: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return "\(formatter.string(from: start))-\(formatter.string(from: end))"
    }
    

    
    private func formattedDate(_ date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()
        
        if calendar.isDateInToday(date) {
            return "Today, \(formatMonthDay(date)), \(formatYear(date))"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday, \(formatMonthDay(date)), \(formatYear(date))"
        } else if calendar.isDate(date, equalTo: now, toGranularity: .weekOfYear) {
            // Within the same week
            let weekdayFormatter = DateFormatter()
            weekdayFormatter.dateFormat = "EEEE"
            return "\(weekdayFormatter.string(from: date)), \(formatMonthDay(date)), \(formatYear(date))"
        } else {
            let weekdayFormatter = DateFormatter()
            weekdayFormatter.dateFormat = "EEEE"
            return "\(weekdayFormatter.string(from: date)), \(formatMonthDay(date)), \(formatYear(date))"
        }
    }
    
    private func formatMonthDay(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
    
    private func formatYear(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy"
        return formatter.string(from: date)
    }
    
    var body: some View {
            ZStack {
                Color("iosbg")
                    .ignoresSafeArea()
                
                VStack(alignment: .leading, spacing: 0) {
                    // Custom header
                    ZStack {
                        // 1) Centered text
                        Text(formattedDate(startTime))
                            .font(.system(size: 17))
                            .fontWeight(.semibold)

                        // 2) Trailing button
                        HStack {
                            Spacer()
                            Button("Done") {
                                dismiss()
                            }
                            .foregroundColor(.accentColor)
                            .font(.system(size: 17))
                            .fontWeight(.semibold)
                        }
                    }
                    .padding(.horizontal)


                    
                    // Content
                    VStack(alignment: .leading, spacing: 24) {
                        // Header section with icon and title
                        HStack(spacing: 15) {
                            Image("pd")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 60, height: 60)
                                .cornerRadius(8)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(pod.title)
                                    .font(.system(size: 16, weight: .regular))
                                
                                Text(formatTimeRange(startTime, endTime))
                                    .font(.system(size: 16, weight: .regular))
                                    .foregroundColor(.gray)
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 20) {
                            HStack {
                                Text("Summary")
                                    .font(.system(size: 24, weight: .bold))
                                
                                Spacer()
                                
                                Button(action: {
                                    navigationAction(.fullSummary(items: items, columns: podColumns))
                                }) {
                                    Text("Show More")
                                        .font(.system(size: 17))
                                        .foregroundColor(.accentColor)
                                }
                            }
                            
                            LazyVGrid(columns: [
                                GridItem(.flexible(), alignment: .leading),
                                GridItem(.flexible(), alignment: .leading)
                            ], spacing: 8) {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Total Time")
                                        .font(.system(size: 16))
                                        .foregroundColor(.primary)
                                    Text(formatDuration(duration))
                                        .font(.system(size: 32, weight: .semibold, design: .rounded))
                                        .foregroundColor(Color("pinkRed"))
                                }
                                
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Items Logged")
                                        .font(.system(size: 16))
                                        .foregroundColor(.primary)
                                    Text("\(getLoggedItemsCount())")
                                        .font(.system(size: 32, weight: .semibold, design: .rounded))
                                        .foregroundColor(Color("teal"))
                                }
                            }
                            .padding()
                            .background(Color("iosnp"))
                            .cornerRadius(12)
                            .frame(maxWidth: .infinity)
                        }

                    }
                    .padding(.horizontal)
                    .padding(.top, 20)
                    
                    Spacer()
                }
            }
            .navigationBarHidden(true)
        }
}
