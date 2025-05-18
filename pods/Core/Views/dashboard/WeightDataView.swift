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
    
    private let dateFormatter = ISO8601DateFormatter()
    
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
            ForEach(logs, id: \.id) { log in
                if let date = dateFormatter.date(from: log.dateLogged) {
                    LineMark(
                        x: .value("Date", date),
                        y: .value("Weight", log.weightKg * 2.20462) // Convert to lbs
                    )
                    .lineStyle(StrokeStyle(lineWidth: 2))
                    .foregroundStyle(Color.purple)
                    
                    PointMark(
                        x: .value("Date", date),
                        y: .value("Weight", log.weightKg * 2.20462) // Convert to lbs
                    )
                    .symbolSize(CGSize(width: 10, height: 10))
                    .foregroundStyle(Color.purple)
                }
            }
        }
        .chartYScale(domain: weightChartRange())
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
        let weights = logs.map { $0.weightKg * 2.20462 } // Convert to lbs
        
        if !weights.isEmpty {
            averageWeight = weights.reduce(0, +) / Double(weights.count)
        } else {
            averageWeight = 0
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
    WeightDataView()
}
