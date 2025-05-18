//
//  WeightDataView.swift
//  Pods
//
//  Created by Dimi Nunez on 5/17/25.
//

import SwiftUI
import Charts

struct WeightDataView: View {
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
    
    @State private var logs: [WeightLogResponse] = []
    @State private var allLogs: [WeightLogResponse] = []
    @State private var timeframe: Timeframe = .week
    @State private var isLoading = false
    @State private var averageWeight: Double = 0
    @State private var dateRangeText: String = ""
    @State private var showingEditSheet = false
    @State private var errorMessage: String? = nil
    
    private let dateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
    
    init(initialAllLogs: [WeightLogResponse] = []) {
        _allLogs = State(initialValue: initialAllLogs)
        _logs = State(initialValue: [])
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                timeframePickerView
                averageWeightView
                
                if let error = errorMessage {
                    errorView(message: error)
                } else {
                    chartView
                }
                
                Spacer()
            }
        }
        .navigationTitle("Weight")
        .navigationBarItems(trailing: Button("Add Data") {
            showingEditSheet = true
        })
        .onAppear {
            loadAllLogs()
        }
        .sheet(isPresented: $showingEditSheet) {
            EditWeightView()
                .onDisappear {
                    // Refresh data when the edit sheet is dismissed
                    loadAllLogs()
                }
        }
    }
    
    // MARK: - View Components
    
    private var timeframePickerView: some View {
        Picker("Timeframe", selection: $timeframe) {
            ForEach(Timeframe.allCases, id: \.self) { tf in
                Text(tf.rawValue)
                    .tag(tf)
            }
        }
        .pickerStyle(SegmentedPickerStyle())
        .padding(.horizontal)
        .onChange(of: timeframe) { _ in
            filterLogs()
        }
    }
    
    private var averageWeightView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("AVERAGE")
                .font(.system(size: 16))
                .foregroundColor(.gray)
            
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(String(format: "%.1f", averageWeight))")
                    .font(.system(size: 60, weight: .bold))
                Text("lbs")
                    .font(.system(size: 32))
                    .foregroundColor(.gray)
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
                weightChart
            }
        }
    }
    
    private var weightChart: some View {
        Chart {
            ForEach(groupedLogsForChart(), id: \.date) { dataPoint in
                LineMark(
                    x: .value("Date", dataPoint.date),
                    y: .value("Weight", dataPoint.weightLbs)
                )
                .lineStyle(StrokeStyle(lineWidth: 2))
                .foregroundStyle(Color.purple)
                
                PointMark(
                    x: .value("Date", dataPoint.date),
                    y: .value("Weight", dataPoint.weightLbs)
                )
                .symbolSize(CGSize(width: 10, height: 10))
                .foregroundStyle(Color.purple)
            }
        }
        .chartYScale(domain: weightChartRange())
        .chartXAxis {
            AxisMarks { value in
                if let date = value.as(Date.self) {
                    AxisValueLabel {
                        switch timeframe {
                        case .day:
                            Text(formatDate(date, format: "HH:mm"))
                        case .week:
                            Text(formatDate(date, format: "EEE"))
                        case .month:
                            Text(formatDate(date, format: "d"))
                        case .sixMonths:
                            Text(formatDate(date, format: "MMM"))
                        case .year:
                            Text(formatDate(date, format: "MMM"))
                        }
                    }
                }
            }
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
    
    // Helper function to format dates
    private func formatDate(_ date: Date, format: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = format
        return formatter.string(from: date)
    }
    
    // Group logs based on timeframe
    private func groupedLogsForChart() -> [ChartDataPoint] {
        guard !logs.isEmpty else { return [] }
        
        var result: [ChartDataPoint] = []
        
        switch timeframe {
        case .day, .week:
            // For day and week, show individual data points
            for log in logs {
                if let date = dateFormatter.date(from: log.dateLogged) {
                    result.append(ChartDataPoint(date: date, weightLbs: log.weightKg * 2.20462))
                }
            }
            
        case .month:
            // Group by day
            let calendar = Calendar.current
            var dayGroups: [Date: [Double]] = [:]
            
            for log in logs {
                if let date = dateFormatter.date(from: log.dateLogged) {
                    let day = calendar.startOfDay(for: date)
                    if dayGroups[day] == nil {
                        dayGroups[day] = []
                    }
                    dayGroups[day]?.append(log.weightKg * 2.20462)
                }
            }
            
            for (day, weights) in dayGroups {
                let avgWeight = weights.reduce(0, +) / Double(weights.count)
                result.append(ChartDataPoint(date: day, weightLbs: avgWeight))
            }
            
        case .sixMonths:
            // Group by week
            let calendar = Calendar.current
            var weekGroups: [Date: [Double]] = [:]
            
            for log in logs {
                if let date = dateFormatter.date(from: log.dateLogged) {
                    let weekOfYear = calendar.component(.weekOfYear, from: date)
                    let year = calendar.component(.year, from: date)
                    
                    // Find start of week
                    guard let startOfWeek = calendar.date(from: DateComponents(weekOfYear: weekOfYear, yearForWeekOfYear: year)) else {
                        continue
                    }
                    
                    if weekGroups[startOfWeek] == nil {
                        weekGroups[startOfWeek] = []
                    }
                    weekGroups[startOfWeek]?.append(log.weightKg * 2.20462)
                }
            }
            
            for (week, weights) in weekGroups {
                let avgWeight = weights.reduce(0, +) / Double(weights.count)
                result.append(ChartDataPoint(date: week, weightLbs: avgWeight))
            }
            
        case .year:
            // Group by month
            let calendar = Calendar.current
            var monthGroups: [Date: [Double]] = [:]
            
            for log in logs {
                if let date = dateFormatter.date(from: log.dateLogged) {
                    let components = calendar.dateComponents([.year, .month], from: date)
                    guard let firstDayOfMonth = calendar.date(from: components) else {
                        continue
                    }
                    
                    if monthGroups[firstDayOfMonth] == nil {
                        monthGroups[firstDayOfMonth] = []
                    }
                    monthGroups[firstDayOfMonth]?.append(log.weightKg * 2.20462)
                }
            }
            
            for (month, weights) in monthGroups {
                let avgWeight = weights.reduce(0, +) / Double(weights.count)
                result.append(ChartDataPoint(date: month, weightLbs: avgWeight))
            }
        }
        
        // Sort by date
        return result.sorted { $0.date < $1.date }
    }
    
    // Chart data point structure
    struct ChartDataPoint: Identifiable {
        var id: Date { date }
        let date: Date
        let weightLbs: Double
    }
    
    // Calculate Y-axis range for the chart
    private func weightChartRange() -> ClosedRange<Double> {
        if logs.isEmpty {
            return 120...180 // Default range if no data
        }
        
        let weights = logs.compactMap { log in
            return log.weightKg * 2.20462 // Convert to lbs
        }
        
        guard let minWeight = weights.min(), let maxWeight = weights.max() else {
            return 120...180
        }
        
        // Add 10% padding above and below
        let padding = (maxWeight - minWeight) * 0.1
        let lowerBound = Swift.max(minWeight - padding, 0)
        let upperBound = maxWeight + padding
        
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
    
    // Update average weight display and date range text
    private func updateAverageAndDateRange() {
        // For the average calculation, we'll use the filtered data
        let weights = logs.map { $0.weightKg * 2.20462 } // Convert to lbs
        
        if !weights.isEmpty {
            averageWeight = weights.reduce(0, +) / Double(weights.count)
        } else {
            averageWeight = 0
        }
        
        // Update date range text based on timeframe
        let calendar = Calendar.current
        let dateFormatter = DateFormatter()
        
        switch timeframe {
        case .day:
            if let date = logs.first?.dateLogged, let parsedDate = self.dateFormatter.date(from: date) {
                dateFormatter.dateFormat = "MMMM d, yyyy"
                dateRangeText = dateFormatter.string(from: parsedDate)
            } else {
                dateRangeText = ""
            }
            
        case .week:
            let today = Date()
            let weekStart = calendar.date(byAdding: .day, value: -6, to: today) ?? today
            
            dateFormatter.dateFormat = "MMM d"
            let startText = dateFormatter.string(from: weekStart)
            let endText = dateFormatter.string(from: today)
            dateRangeText = "\(startText)-\(endText), \(calendar.component(.year, from: today))"
            
        case .month:
            dateFormatter.dateFormat = "MMMM yyyy"
            dateRangeText = dateFormatter.string(from: Date())
            
        case .sixMonths:
            let now = Date()
            let sixMonthsAgo = calendar.date(byAdding: .month, value: -6, to: now) ?? now
            
            dateFormatter.dateFormat = "MMM yyyy"
            let startText = dateFormatter.string(from: sixMonthsAgo)
            let endText = dateFormatter.string(from: now)
            dateRangeText = "\(startText) - \(endText)"
            
        case .year:
            let now = Date()
            dateFormatter.dateFormat = "yyyy"
            dateRangeText = dateFormatter.string(from: now)
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
        if let preloadedData = UserDefaults.standard.data(forKey: "preloadedWeightLogs"),
           let response = try? JSONDecoder().decode(WeightLogsResponse.self, from: preloadedData) {
            
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
        
        NetworkManagerTwo.shared.fetchWeightLogs(userEmail: email, limit: 1000, offset: 0) { result in
            self.isLoading = false
            
            switch result {
            case .success(let response):
                DispatchQueue.main.async {
                    self.errorMessage = nil
                    
                    // Save to UserDefaults for future use
                    if let encodedData = try? JSONEncoder().encode(response) {
                        UserDefaults.standard.set(encodedData, forKey: "preloadedWeightLogs")
                    }
                    
                    if response.logs.isEmpty {
                        print("No weight logs found for user")
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
                    self.errorMessage = "Failed to load weight data: \(error.localizedDescription)"
                    print("Error fetching weight logs: \(error)")
                }
            }
        }
    }
}

#Preview {
    WeightDataView(initialAllLogs: [])
}
