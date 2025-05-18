//
//  HeightDataView.swift
//  Pods
//
//  Created by Dimi Nunez on 5/17/25.
//

import SwiftUI
import Charts

struct HeightDataView: View {
    enum Timeframe: String, CaseIterable {
        case day = "D"
        case week = "W"
        case month = "M"
        case sixMonths = "6M"
        case year = "Y"
        
        var days: Int {
            switch self {
            case .day: return 1
            case .week: return 7
            case .month: return 30
            case .sixMonths: return 182
            case .year: return 365
            }
        }
    }
    
    @State private var logs: [HeightLogResponse] = []
    @State private var allLogs: [HeightLogResponse] = []
    @State private var timeframe: Timeframe = .week
    @State private var isLoading = false
    @State private var averageHeight: Double = 0
    @State private var dateRangeText: String = ""
    @State private var showingEditSheet = false
    @State private var errorMessage: String? = nil
    
    private let dateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
    
    // Add initializer with initialAllLogs parameter
    init(initialAllLogs: [HeightLogResponse] = []) {
        _allLogs = State(initialValue: initialAllLogs)
        _logs = State(initialValue: [])
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                timeframePickerView
                averageHeightView
                
                if let error = errorMessage {
                    errorView(message: error)
                } else {
                    chartView
                }
                
                Spacer()
            }
        }
        .navigationTitle("Height")
        .navigationBarItems(trailing: Button("Add Data") {
            showingEditSheet = true
        })
        .onAppear {
            loadAllLogs()
        }
        .sheet(isPresented: $showingEditSheet) {
            EditHeightView()
                .onDisappear {
                    // Refresh data when the edit sheet is dismissed
                    loadAllLogs()
                }
        }
    }
    
    // MARK: - View Components
    
    private var timeframePickerView: some View {
        HStack(spacing: 0) {
            ForEach(Timeframe.allCases, id: \.self) { tf in
                Button(action: {
                    timeframe = tf
                    filterLogs()
                }) {
                    Text(tf.rawValue)
                        .font(.system(size: 16, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(timeframe == tf ? Color.white : Color.clear)
                        .foregroundColor(timeframe == tf ? .black : .gray)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .background(Color(UIColor.systemGray5))
        .cornerRadius(8)
        .padding(.horizontal)
    }
    
    private var averageHeightView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("AVERAGE")
                .font(.system(size: 16))
                .foregroundColor(.gray)
            
            if averageHeight > 0 {
                let feet = Int(averageHeight / 30.48)
                let remainingCm = averageHeight.truncatingRemainder(dividingBy: 30.48)
                let inches = Int(remainingCm / 2.54)
                
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(feet)' \(inches)\"")
                        .font(.system(size: 60, weight: .bold))
                }
            } else {
                Text("No data")
                    .font(.system(size: 60, weight: .bold))
            }
            
            Text(dateRangeText)
                .font(.system(size: 16))
                .foregroundColor(.gray)
        }
        .padding(.horizontal)
        .padding(.top, 10)
    }
    
    private var chartView: some View {
        Group {
            if isLoading {
                ProgressView()
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .center)
            } else if logs.isEmpty {
                Text("No data for this time period")
                    .foregroundColor(.gray)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                heightChart
            }
        }
    }
    
    private var heightChart: some View {
        Chart {
            ForEach(logs, id: \.id) { log in
                if let date = dateFormatter.date(from: log.dateLogged) {
                    LineMark(
                        x: .value("Date", date),
                        y: .value("Height", log.heightCm)
                    )
                    .lineStyle(StrokeStyle(lineWidth: 2))
                    .foregroundStyle(Color.purple)
                    
                    PointMark(
                        x: .value("Date", date),
                        y: .value("Height", log.heightCm)
                    )
                    .symbolSize(CGSize(width: 10, height: 10))
                    .foregroundStyle(Color.purple)
                }
            }
        }
        .chartYScale(domain: heightChartRange())
        .chartXAxis {
            AxisMarks(preset: .aligned, position: .bottom)
        }
        .chartYAxis {
            AxisMarks(preset: .aligned, position: .leading)
        }
        .frame(height: 300)
        .padding()
    }
    
    private func errorView(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundColor(.orange)
            
            Text("Error Loading Data")
                .font(.headline)
            
            Text(message)
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
                .foregroundColor(.secondary)
            
            Button(action: {
                loadAllLogs()
            }) {
                Text("Try Again")
                    .fontWeight(.medium)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            .padding()
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color("iosnp"))
        .cornerRadius(12)
        .padding()
    }
    
    // MARK: - Helper Methods
    
    // Determines appropriate date format based on timeframe
    private func dayFormatter() -> String {
        switch timeframe {
        case .day: return "HH:mm"
        case .week: return "EEE"
        case .month: return "dd"
        case .sixMonths, .year: return "MMM"
        }
    }
    
    // Calculate Y-axis range for the chart
    private func heightChartRange() -> ClosedRange<Double> {
        if logs.isEmpty {
            return 160...190 // Default range if no data
        }
        
        let heights = logs.compactMap { log in
            return log.heightCm
        }
        
        guard let minHeight = heights.min(), let maxHeight = heights.max() else {
            return 160...190
        }
        
        // Add 10% padding above and below
        let padding = (maxHeight - minHeight) * 0.1
        let lowerBound = Swift.max(minHeight - padding, 0)
        let upperBound = maxHeight + padding
        
        // Ensure at least 10 units of range
        if upperBound - lowerBound < 10 {
            return (lowerBound - 5)...(upperBound + 5)
        }
        
        return lowerBound...upperBound
    }
    
    // Filter logs based on selected timeframe
    private func filterLogs() {
        let cutoff = Calendar.current.date(byAdding: .day, value: -timeframe.days, to: Date()) ?? Date()
        
        logs = allLogs.filter { log in
            if let date = dateFormatter.date(from: log.dateLogged) {
                return date >= cutoff
            }
            return false
        }.sorted { log1, log2 in
            guard let d1 = dateFormatter.date(from: log1.dateLogged),
                  let d2 = dateFormatter.date(from: log2.dateLogged) else { return false }
            return d1 < d2
        }
        
        updateAverageAndDateRange()
    }
    
    // Update average height display and date range text
    private func updateAverageAndDateRange() {
        let heights = logs.map { $0.heightCm } // Heights in cm
        
        if !heights.isEmpty {
            averageHeight = heights.reduce(0, +) / Double(heights.count)
        } else {
            averageHeight = 0
        }
        
        // Update date range text
        if !logs.isEmpty, let firstDate = logs.first?.dateLogged, let lastDate = logs.last?.dateLogged,
           let firstDateObj = dateFormatter.date(from: firstDate),
           let lastDateObj = dateFormatter.date(from: lastDate) {
            
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "MMM d"
            
            if Calendar.current.isDate(firstDateObj, inSameDayAs: lastDateObj) {
                dateRangeText = dateFormatter.string(from: firstDateObj) + ", 2025"
            } else {
                dateRangeText = dateFormatter.string(from: firstDateObj) + "–" + 
                                dateFormatter.string(from: lastDateObj) + ", 2025"
            }
        } else {
            dateRangeText = ""
        }
    }
    
    // Load all logs and then filter for the selected timeframe
    private func loadAllLogs() {
        isLoading = true
        
        // If we have initialAllLogs, use them directly
        if !allLogs.isEmpty {
            DispatchQueue.main.async {
                self.isLoading = false
                self.filterLogs()
                
                // Still refresh in background for most up-to-date data
                self.refreshDataFromNetwork()
            }
            return
        }
        
        // First check if preloaded data exists in UserDefaults
        if let preloadedData = UserDefaults.standard.data(forKey: "preloadedHeightLogs"),
           let response = try? JSONDecoder().decode(HeightLogsResponse.self, from: preloadedData) {
            
            DispatchQueue.main.async {
                self.isLoading = false
                self.allLogs = response.logs.sorted { log1, log2 in
                    guard let d1 = self.dateFormatter.date(from: log1.dateLogged),
                          let d2 = self.dateFormatter.date(from: log2.dateLogged) else { return false }
                    return d1 < d2
                }
                
                self.filterLogs()
                
                // Refresh in background for most up-to-date data
                self.refreshDataFromNetwork()
            }
            return
        }
        
        // If no preloaded data, load from network
        refreshDataFromNetwork()
    }
    
    // Fetch fresh data from the network
    private func refreshDataFromNetwork() {
        guard let email = UserDefaults.standard.string(forKey: "userEmail") else {
            isLoading = false
            errorMessage = "No user email found. Please sign in again."
            return
        }
        
        NetworkManagerTwo.shared.fetchHeightLogs(userEmail: email, limit: 1000, offset: 0) { result in
            self.isLoading = false
            
            switch result {
            case .success(let response):
                DispatchQueue.main.async {
                    self.errorMessage = nil
                    
                    // Save to UserDefaults for future use
                    if let encodedData = try? JSONEncoder().encode(response) {
                        UserDefaults.standard.set(encodedData, forKey: "preloadedHeightLogs")
                    }
                    
                    if response.logs.isEmpty {
                        print("No height logs found for user")
                    } else {
                        self.allLogs = response.logs.sorted { log1, log2 in
                            guard let d1 = self.dateFormatter.date(from: log1.dateLogged),
                                  let d2 = self.dateFormatter.date(from: log2.dateLogged) else { return false }
                            return d1 < d2
                        }
                        
                        self.filterLogs()
                    }
                }
                
            case .failure(let error):
                DispatchQueue.main.async {
                    self.errorMessage = "Failed to load height data: \(error.localizedDescription)"
                    print("Error fetching height logs: \(error)")
                }
            }
        }
    }
}

#Preview {
    HeightDataView()
}
