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
        case week = "W"
        case month = "M"
        case threeMonths = "3M"
        case sixMonths = "6M"
        case year = "Y"
        
        var days: Int {
            switch self {
            case .week: return 7
            case .month: return 30
            case .threeMonths: return 91
            case .sixMonths: return 182
            case .year: return 365
            }
        }
    }
    
    @State private var logs: [HeightLogResponse] = []
    @State private var allLogs: [HeightLogResponse] = []
    @State private var timeframe: Timeframe = .threeMonths
    @State private var isLoading = false
    @State private var currentHeight: Double = 0
    @State private var dateRangeText: String = ""
    @State private var showingEditSheet = false
    @State private var errorMessage: String? = nil
    @State private var selectedDataPoint: ChartDataPoint? = nil
    @State private var isChartTapped = false
    @State private var selectedLogForEdit: HeightLogResponse? = nil
    @Environment(\.isTabBarVisible) private var isTabBarVisible
    
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
        // Single List containing everything for smooth scrolling
        List {
            // Header content as list sections
            Section {
                timeframePickerView
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                
                averageHeightView
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                
                if let error = errorMessage {
                    errorView(message: error)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                } else {
                    chartView
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
            }
            
            // History section
            if !logs.isEmpty && errorMessage == nil {
                Section {
                    // History header
                    HStack {
                        Text("History")
                            .font(.title)
                            .foregroundColor(.primary)
                            .fontWeight(.bold)
                        
                        Spacer()
                    }
                    .padding(.horizontal)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
                
                // History logs with swipe-to-delete
                ForEach(logs.reversed(), id: \.id) { log in
                    if let date = dateFormatter.date(from: log.dateLogged) {
                        HeightLogRowView(
                            log: log,
                            date: date,
                            onRowTap: {
                                selectedLogForEdit = log
                            }
                        )
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        .listRowBackground(Color.clear)
                    }
                }
                .onDelete(perform: deleteItems)
            }
        }
        .listStyle(PlainListStyle())
        .scrollContentBackground(.hidden)
        .environment(\.defaultMinListRowHeight, 0)
        .navigationTitle("Height")
        .navigationBarItems(trailing: Button("Add Data") {
            showingEditSheet = true
        })
        .onAppear {
            loadAllLogs()
            isTabBarVisible.wrappedValue = false
        }
        .onDisappear {
            isTabBarVisible.wrappedValue = true
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("HeightLogDeletedNotification"))) { _ in
            // Refresh data when a height log is deleted
            refreshDataFromNetwork()
        }
        .sheet(isPresented: $showingEditSheet) {
            EditHeightView()
                .onDisappear {
                    // Refresh data when the edit sheet is dismissed
                    loadAllLogs()
                }
        }
        .sheet(item: $selectedLogForEdit) { log in
            UpdateEditHeightView(heightLog: log)
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
    
    private var averageHeightView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("CURRENT")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.gray)
            
            if currentHeight > 0 {
                let totalInches = currentHeight / 2.54
                let feet = Int(totalInches / 12)
                let inches = Int(totalInches.truncatingRemainder(dividingBy: 12).rounded())
                
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(feet)' \(inches)\"")
                        .font(.system(size: 44, weight: .semibold, design: .rounded))
                }
            } else {
                Text("No data")
                    .font(.system(size: 60, weight: .bold))
            }
            
            Text(dateRangeText)
                .font(.system(size: 16))
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
            ForEach(groupedLogsForChart(), id: \.date) { dataPoint in
                LineMark(
                    x: .value("Date", dataPoint.date),
                    y: .value("Height", dataPoint.heightCm)
                )
                .lineStyle(StrokeStyle(lineWidth: 2))
                .foregroundStyle(Color.purple)

                // Mask the line so it doesn’t show through the hollow point
                PointMark(
                    x: .value("Date", dataPoint.date),
                    y: .value("Height", dataPoint.heightCm)
                )
                .symbol(.circle)
                .symbolSize(CGSize(width: 12, height: 12))        // slightly larger mask
                .foregroundStyle(Color(UIColor.systemBackground))  // background-colored fill

                // Outlined hollow point
                PointMark(
                    x: .value("Date", dataPoint.date),
                    y: .value("Height", dataPoint.heightCm)
                )
                .symbol(.circle.strokeBorder(lineWidth: 2))
                .symbolSize(CGSize(width: 10, height: 10))
                .foregroundStyle(Color.purple)
            }
            
            // Add a vertical rule mark at the selected point
            if let selectedPoint = selectedDataPoint, isChartTapped {
                RuleMark(x: .value("Selected Date", selectedPoint.date))
                    .foregroundStyle(Color.gray.opacity(0.7))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
                    
                PointMark(
                    x: .value("Selected Date", selectedPoint.date),
                    y: .value("Selected Height", selectedPoint.heightCm)
                )
                .symbolSize(CGSize(width: 14, height: 14))
                .foregroundStyle(Color.purple)
                .annotation(position: .top) {
                    VStack(alignment: .center, spacing: 4) {
                        // Calculate feet and inches
                        let totalInches = selectedPoint.heightCm / 2.54
                        let feet = Int(totalInches / 12)
                        let inches = Int(totalInches.truncatingRemainder(dividingBy: 12).rounded())
                        
                        Text("\(feet)' \(inches)\"")
                            .font(.headline)
                            .foregroundColor(.primary)
                        Text(formatDate(selectedPoint.date, format: "MMM d, yyyy"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(UIColor.systemBackground))
                            .shadow(radius: 2)
                    )
                }
            }
        }
        .chartYScale(domain: heightChartRange())
        .chartXAxis {
            AxisMarks { value in
                if let date = value.as(Date.self) {
                    AxisGridLine()
                    AxisValueLabel {
                        switch timeframe {
                        case .week:
                            Text(formatDate(date, format: "EEE"))
                        case .month:
                            Text(formatDate(date, format: "d"))
                        case .threeMonths:
                            Text(formatDate(date, format: "MMM"))
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
            AxisMarks(preset: .aligned, position: .leading) { value in
                AxisGridLine()
                AxisValueLabel {
                    Text(value.as(Double.self)?.formatted() ?? "")
                }
            }
        }
        .frame(height: 300)
        .padding()
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    findClosestDataPoint(at: value.location)
                    isChartTapped = true
                }
                .onEnded { _ in
                    // Keep the selection visible
                }
        )
        .onTapGesture {
            // Handle simple taps outside data points
            isChartTapped = false
            selectedDataPoint = nil
        }
    }
    

    
    private func errorView(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundColor(.purple)
            
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
    
    // Helper function to format dates for history section
    private func formatDateForHistory(_ date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()
        
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else if let daysAgo = calendar.dateComponents([.day], from: date, to: now).day, daysAgo <= 7 {
            // Within a week - show day name
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE"
            return formatter.string(from: date)
        } else {
            // Older than a week - show date
            let formatter = DateFormatter()
            formatter.dateFormat = "M/d/yy"
            return formatter.string(from: date)
        }
    }
    
    private func deleteItems(offsets: IndexSet) {
        let reversedLogs = logs.reversed()
        for index in offsets {
            let logToDelete = Array(reversedLogs)[index]
            deleteHeightLog(logToDelete)
        }
    }
    
    private func deleteHeightLog(_ log: HeightLogResponse) {
        NetworkManagerTwo.shared.deleteHeightLog(logId: log.id) { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    print("✅ Height log deleted successfully via swipe")
                    // Post notification to refresh the height data view
                    NotificationCenter.default.post(name: Notification.Name("HeightLogDeletedNotification"), object: nil)
                    
                case .failure(let error):
                    print("❌ Error deleting height log via swipe: \(error)")
                    // TODO: Show error alert to user
                }
            }
        }
    }
    
    // Group logs based on timeframe
    private func groupedLogsForChart() -> [ChartDataPoint] {
        guard !logs.isEmpty else { return [] }
        
        var result: [ChartDataPoint] = []
        
        switch timeframe {
        case .week:
            // For week, show individual data points
            for log in logs {
                if let date = dateFormatter.date(from: log.dateLogged) {
                    result.append(ChartDataPoint(date: date, heightCm: log.heightCm))
                }
            }
            
        case .month, .threeMonths:
            // Group by day
            let calendar = Calendar.current
            var dayGroups: [Date: [Double]] = [:]
            
            for log in logs {
                if let date = dateFormatter.date(from: log.dateLogged) {
                    let day = calendar.startOfDay(for: date)
                    if dayGroups[day] == nil {
                        dayGroups[day] = []
                    }
                    dayGroups[day]?.append(log.heightCm)
                }
            }
            
            for (day, heights) in dayGroups {
                let avgHeight = heights.reduce(0, +) / Double(heights.count)
                result.append(ChartDataPoint(date: day, heightCm: avgHeight))
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
                    weekGroups[startOfWeek]?.append(log.heightCm)
                }
            }
            
            for (week, heights) in weekGroups {
                let avgHeight = heights.reduce(0, +) / Double(heights.count)
                result.append(ChartDataPoint(date: week, heightCm: avgHeight))
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
                    monthGroups[firstDayOfMonth]?.append(log.heightCm)
                }
            }
            
            for (month, heights) in monthGroups {
                let avgHeight = heights.reduce(0, +) / Double(heights.count)
                result.append(ChartDataPoint(date: month, heightCm: avgHeight))
            }
        }
        
        // Sort by date
        return result.sorted { $0.date < $1.date }
    }
    
    // Chart data point structure
    struct ChartDataPoint: Identifiable {
        var id: Date { date }
        let date: Date
        let heightCm: Double
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
    
    // Update current height display and date range text
    private func updateAverageAndDateRange() {
        // For the current height, we'll use the most recent entry
        if let mostRecentLog = logs.sorted(by: { log1, log2 in
            guard let d1 = self.dateFormatter.date(from: log1.dateLogged),
                  let d2 = self.dateFormatter.date(from: log2.dateLogged) else { return false }
            return d1 > d2
        }).first {
            currentHeight = mostRecentLog.heightCm
        } else {
            currentHeight = 0
        }
        
        // Update date range text based on timeframe
        let calendar = Calendar.current
        let dateFormatter = DateFormatter()
        
        switch timeframe {
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
            
        case .threeMonths:
            let now = Date()
            let threeMonthsAgo = calendar.date(byAdding: .month, value: -3, to: now) ?? now
            
            dateFormatter.dateFormat = "MMM yyyy"
            let startText = dateFormatter.string(from: threeMonthsAgo)
            let endText = dateFormatter.string(from: now)
            dateRangeText = "\(startText) - \(endText)"
            
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
    
    // Helper method to find the closest data point to a tap location
    private func findClosestDataPoint(at location: CGPoint) {
        // Convert back from tap coordinates to chart coordinates
        let chartWidth: CGFloat = 300 // Estimate of the chart width
        let chartHeight: CGFloat = 300
        
        let dataPoints = groupedLogsForChart()
        guard !dataPoints.isEmpty else { return }
        
        // Map tap X position to a date based on relative position
        let dateRange = getDateRange()
        guard let startDate = dateRange.0, let endDate = dateRange.1 else { return }
        
        let totalTimeInterval = endDate.timeIntervalSince(startDate)
        let xRatio = min(max(location.x / chartWidth, 0), 1)
        let estimatedDate = startDate.addingTimeInterval(totalTimeInterval * Double(xRatio))
        
        // Find closest data point
        var closestPoint = dataPoints[0]
        var minDistance: TimeInterval = abs(estimatedDate.timeIntervalSince(closestPoint.date))
        
        for point in dataPoints {
            let distance = abs(estimatedDate.timeIntervalSince(point.date))
            if distance < minDistance {
                minDistance = distance
                closestPoint = point
            }
        }
        
        selectedDataPoint = closestPoint
    }
    
    // Helper to get the date range of the current dataset
    private func getDateRange() -> (Date?, Date?) {
        let sortedPoints = groupedLogsForChart().sorted { $0.date < $1.date }
        return (sortedPoints.first?.date, sortedPoints.last?.date)
    }
}

// MARK: - HeightLogRowView Component
struct HeightLogRowView: View {
    let log: HeightLogResponse
    let date: Date
    let onRowTap: () -> Void
    
    private func formatDateForHistory(_ date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()
        
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else if let daysAgo = calendar.dateComponents([.day], from: date, to: now).day, daysAgo <= 7 {
            // Within a week - show day name
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE"
            return formatter.string(from: date)
        } else {
            // Older than a week - show date
            let formatter = DateFormatter()
            formatter.dateFormat = "M/d/yy"
            return formatter.string(from: date)
        }
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                // Height in feet and inches
                let totalInches = log.heightCm / 2.54
                let feet = Int(totalInches / 12)
                let inches = Int(totalInches.truncatingRemainder(dividingBy: 12).rounded())
                
                Text("\(feet)' \(inches)\"")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.primary)
                
                Text(formatDateForHistory(date))
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .onTapGesture(perform: onRowTap)
        .background(Color(UIColor.systemBackground))
    }
}

#Preview {
    HeightDataView()
}
