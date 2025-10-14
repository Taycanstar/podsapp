//
//  WeightDataView.swift
//  Pods
//
//  Created by Dimi Nunez on 5/17/25.
//

import SwiftUI
import Charts
import HealthKit
import Combine

struct WeightDataView: View {
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
    
    @State private var logs: [WeightLogResponse] = []
    @State private var allLogs: [WeightLogResponse] = []
    @State private var timeframe: Timeframe = .threeMonths
    @State private var isLoading = false
    @State private var isLoadingMore = false
    @State private var hasMoreLogs = true
    @State private var currentPage = 1
    private let pageSize = 20
    @State private var currentWeight: Double = 0
    @State private var dateRangeText: String = ""
    @State private var showingEditSheet = false
    @State private var errorMessage: String? = nil
    @State private var selectedDataPoint: ChartDataPoint? = nil
    @State private var isChartTapped = false
    @State private var isCompareMode = false
    @State private var selectedLogsForComparison: Set<Int> = []
    @State private var showingCompareView = false
    @State private var selectedLogForEdit: WeightLogResponse? = nil
    @State private var showingFullScreenPhoto = false
    @State private var fullScreenPhotoUrl: String = ""
    @State private var fullScreenImage: UIImage? = nil
    @State private var loadedImages: [String: UIImage] = [:]
    @Environment(\.isTabBarVisible) private var isTabBarVisible
    @EnvironmentObject var viewModel: OnboardingViewModel
    
    // Apple Health sync integration
    @StateObject private var weightSyncService = WeightSyncService.shared
    @State private var showSyncIndicator = false
    @State private var hasCheckedForNewWeights = false
    
    private let dateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
    
    // Computed properties for unit display
    private var weightUnit: String {
        switch viewModel.unitsSystem {
        case .imperial:
            return "lbs"
        case .metric:
            return "kg"
        }
    }
    
    private func formatWeight(_ weightKg: Double) -> String {
        switch viewModel.unitsSystem {
        case .imperial:
            let weightLbs = weightKg * 2.20462
            return String(format: "%.1f", weightLbs)
        case .metric:
            return String(format: "%.1f", weightKg)
        }
    }
    
    private func getDisplayWeight(_ weightKg: Double) -> Double {
        switch viewModel.unitsSystem {
        case .imperial:
            return weightKg * 2.20462
        case .metric:
            return weightKg
        }
    }
    
    init(initialAllLogs: [WeightLogResponse] = []) {
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
                
                averageWeightView
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
            if !allLogs.isEmpty && errorMessage == nil {
                Section {
                    // History header with summary
                    VStack(spacing: 8) {
                        HStack {
                            Text("History")
                                .font(.title)
                                .foregroundColor(.primary)
                                .fontWeight(.bold)
                                .padding()
                            
                            Spacer()
                            
                            compareButton
                        }
                        
                        // Summary of logs
                        HStack {
                            let appleHealthCount = allLogs.filter { $0.notes?.contains("Apple Health") == true || $0.notes?.contains("Withings") == true }.count
                            let manualCount = allLogs.count - appleHealthCount
                            
                            HStack(spacing: 4) {
                                Image(systemName: "heart.text.square")
                                    .font(.system(size: 12))
                                    .foregroundColor(.pink)
                                Text("\(appleHealthCount) Apple Health")
                                    .font(.system(size: 12))
                                    .foregroundColor(.pink)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.pink.opacity(0.1))
                            .cornerRadius(6)
                            
                            HStack(spacing: 4) {
                                Image(systemName: "plus.circle")
                                    .font(.system(size: 12))
                                    .foregroundColor(.blue)
                                Text("\(manualCount) Manual")
                                    .font(.system(size: 12))
                                    .foregroundColor(.blue)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(6)
                            
                            Spacer()
                        }
                        .padding(.horizontal)
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
                
                // History logs with swipe-to-delete and pagination
                ForEach(Array(allLogs.enumerated()), id: \.element.id) { index, log in
                    if let date = parseDate(log.dateLogged) {
                        VStack(spacing: 0) {
                            WeightLogRowView(
                                log: log,
                                date: date,
                                isCompareMode: isCompareMode,
                                isSelected: selectedLogsForComparison.contains(log.id),
                                loadedImages: loadedImages,
                                onToggleSelection: { toggleLogSelection(log.id) },
                                onPhotoTap: { photoUrl in
                                    if let cachedImage = loadedImages[photoUrl] {
                                        fullScreenImage = cachedImage
                                        fullScreenPhotoUrl = ""
                                    } else {
                                        fullScreenPhotoUrl = photoUrl
                                        fullScreenImage = nil
                                    }
                                    showingFullScreenPhoto = true
                                },
                                onCameraTap: { selectedLogForEdit = log },
                                onRowTap: {
                                    if isCompareMode {
                                        toggleLogSelection(log.id)
                                    } else {
                                        selectedLogForEdit = log
                                    }
                                },
                                onImageLoaded: { url, image in
                                    loadedImages[url] = image
                                }
                            )
                            .onAppear {
                                // Load more logs when approaching the end of the list
                                if index >= allLogs.count - 5 && hasMoreLogs && !isLoadingMore {
                                    loadMoreLogs()
                                }
                            }
                            
                            // Add divider except for the last item
                            if index < allLogs.count - 1 {
                                Divider()
                                    .padding(.leading, 16)
                            }
                        }
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                    } else {
                        // Show logs with unparseable dates too, but with a placeholder date
                        VStack(spacing: 0) {
                            WeightLogRowView(
                                log: log,
                                date: Date(), // Fallback to current date
                                isCompareMode: isCompareMode,
                                isSelected: selectedLogsForComparison.contains(log.id),
                                loadedImages: loadedImages,
                                onToggleSelection: { toggleLogSelection(log.id) },
                                onPhotoTap: { photoUrl in
                                    if let cachedImage = loadedImages[photoUrl] {
                                        fullScreenImage = cachedImage
                                        fullScreenPhotoUrl = ""
                                    } else {
                                        fullScreenPhotoUrl = photoUrl
                                        fullScreenImage = nil
                                    }
                                    showingFullScreenPhoto = true
                                },
                                onCameraTap: { selectedLogForEdit = log },
                                onRowTap: {
                                    if isCompareMode {
                                        toggleLogSelection(log.id)
                                    } else {
                                        selectedLogForEdit = log
                                    }
                                },
                                onImageLoaded: { url, image in
                                    loadedImages[url] = image
                                }
                            )
                            .onAppear {
                                // Load more logs when approaching the end of the list
                                if index >= allLogs.count - 5 && hasMoreLogs && !isLoadingMore {
                                    loadMoreLogs()
                                }
                            }
                            
                            // Add divider except for the last item
                            if index < allLogs.count - 1 {
                                Divider()
                                    .padding(.leading, 16)
                            }
                        }
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                    }
                }
                .onDelete(perform: deleteItems)
                
                // Loading indicator for pagination
                if isLoadingMore && hasMoreLogs {
                    HStack {
                        Spacer()
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Loading more...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .padding(.vertical, 8)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
            }
            
        }
        .listStyle(PlainListStyle())
        .scrollContentBackground(.hidden)
        .environment(\.defaultMinListRowHeight, 0)
        .refreshable {
            await refreshData()
        }
        .safeAreaInset(edge: .bottom) {
            // Compare footer (only show when in compare mode)
            if isCompareMode {
                compareFooter
            }
        }
        .navigationTitle("Weight")
        .navigationBarItems(trailing: Button("Add Data") {
            showingEditSheet = true
        })
        .onAppear {
            loadInitialLogs()
            isTabBarVisible.wrappedValue = false
            
            // Check for new Apple Health weights to sync
            if !hasCheckedForNewWeights {
                hasCheckedForNewWeights = true
                Task {
                    let hasNewWeights = await weightSyncService.hasNewWeightsToSync()
                    await MainActor.run {
                        showSyncIndicator = hasNewWeights
                        
                        // Auto-sync if user has HealthKit available and there are new weights
                        if hasNewWeights && HealthKitManager.shared.isHealthDataAvailable {
                            print("🍎 Auto-syncing Apple Health weights")
                            Task {
                                await weightSyncService.syncAppleHealthWeights()
                            }
                        }
                    }
                }
            }
        }
        .onDisappear {
            isTabBarVisible.wrappedValue = true
        }
        .onReceive(
            NotificationCenter.default
                .publisher(for: Notification.Name("WeightLoggedNotification"))
                .receive(on: RunLoop.main)
        ) { _ in
            // Refresh data when a new weight is logged
            refreshFromNetwork()
        }
        .onReceive(
            NotificationCenter.default
                .publisher(for: Notification.Name("WeightLogDeletedNotification"))
                .receive(on: RunLoop.main)
        ) { _ in
            // Refresh data when a weight log is deleted
            refreshFromNetwork()
        }
        .onReceive(
            NotificationCenter.default
                .publisher(for: Notification.Name("WeightLogUpdatedNotification"))
                .receive(on: RunLoop.main)
        ) { notification in
            // Refresh data when a weight log is updated
            refreshFromNetwork()
        }
        .onReceive(
            NotificationCenter.default
                .publisher(for: Notification.Name("AppleHealthWeightSynced"))
                .receive(on: RunLoop.main)
        ) { _ in
            // Refresh data when Apple Health weights are synced
            print("🍎 Apple Health weights synced - refreshing weight data")
            showSyncIndicator = false
            
            // Add a small delay to ensure database transaction is committed
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                print("🍎 Delayed refresh starting...")
                refreshFromNetwork()
            }
        }
        .onReceive(
            NotificationCenter.default
                .publisher(for: Notification.Name("HealthKitPermissionsChanged"))
                .receive(on: RunLoop.main)
        ) { _ in
            // Check for new weights when HealthKit permissions change
            Task {
                let hasNewWeights = await weightSyncService.hasNewWeightsToSync()
                await MainActor.run {
                    showSyncIndicator = hasNewWeights
                }
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            EditWeightView()
                .onDisappear {
                    // Refresh data when the edit sheet is dismissed
                    loadInitialLogs()
                }
        }
        .sheet(isPresented: $showingCompareView) {
            let selectedLogs = allLogs.filter { selectedLogsForComparison.contains($0.id) }
            CompareWeightLogsView(selectedLogs: selectedLogs)
        }
        .sheet(item: $selectedLogForEdit) { log in
            UpdateEditWeightView(weightLog: log)
        }
        .fullScreenCover(isPresented: $showingFullScreenPhoto) {
            if !fullScreenPhotoUrl.isEmpty {
                FullScreenPhotoView(photoUrl: fullScreenPhotoUrl)
            } else if let image = fullScreenImage {
                FullScreenPhotoView(preloadedImage: image)
            }
        }
    }
    
    // MARK: - View Components
    
    private var compareButton: some View {
        Button(action: {
            if isCompareMode {
                // Cancel compare mode
                isCompareMode = false
                selectedLogsForComparison.removeAll()
            } else {
                // Enter compare mode
                isCompareMode = true
            }
        }) {
            Text(isCompareMode ? "Cancel" : "Compare")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color("iosbtn"))
                .clipShape(Capsule())
        }
    }
    
    private var compareFooter: some View {
        VStack(spacing: 0) {
            Divider()
                .background(Color.gray.opacity(0.3))
            
            Button(action: {
                if selectedLogsForComparison.count == 2 {
                    showingCompareView = true
                }
            }) {
                HStack {
                    Spacer()
                    Text("Compare Photos")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(selectedLogsForComparison.count == 2 ? .accentColor : .secondary)
                    Spacer()
                }
                .padding(.vertical, 16)
            }
            .disabled(selectedLogsForComparison.count != 2)
        }
        .background(Color(UIColor.systemBackground))
        .shadow(color: Color.black.opacity(0.1), radius: 1, x: 0, y: -1)
    }
    
    private var timeframePickerView: some View {
        VStack(spacing: 12) {
            // Timeframe picker
            Picker("Timeframe", selection: $timeframe) {
                ForEach(Timeframe.allCases, id: \.self) { tf in
                    Text(tf.rawValue)
                        .tag(tf)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .onChange(of: timeframe) { _ in
                filterLogs()
            }
            

        }
        .padding(.horizontal)
    }
    
    private var averageWeightView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("CURRENT")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.gray)
            
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(String(format: "%.1f", currentWeight))")
                              .font(.system(size: 28, weight: .semibold, design: .rounded))
                Text(weightUnit)
                    .font(.system(size: 22))
                    .foregroundColor(.gray)
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
                weightChart
            }
        }
    }
    
    private var weightChart: some View {
        Chart {
            ForEach(groupedLogsForChart(), id: \.date) { dataPoint in
                LineMark(
                    x: .value("Date", dataPoint.date),
                    y: .value("Weight", dataPoint.displayWeight)
                )
                .lineStyle(StrokeStyle(lineWidth: 2))
                .foregroundStyle(Color.purple)
                
                // Mask the line so it doesn't show through the hollow point
                PointMark(
                    x: .value("Date", dataPoint.date),
                    y: .value("Weight", dataPoint.displayWeight)
                )
                .symbol(.circle)
                .symbolSize(CGSize(width: 12, height: 12))        // slightly larger
                .foregroundStyle(Color(UIColor.systemBackground))  // background-colored fill

                // Outlined hollow point
                PointMark(
                    x: .value("Date", dataPoint.date),
                    y: .value("Weight", dataPoint.displayWeight)
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
                    y: .value("Selected Weight", selectedPoint.displayWeight)
                )
                .symbolSize(CGSize(width: 14, height: 14))
                .foregroundStyle(Color.purple)
                .annotation(position: .top) {
                    VStack(alignment: .center, spacing: 4) {
                        Text("\(String(format: "%.1f", selectedPoint.displayWeight)) \(weightUnit)")
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
        .chartYScale(domain: weightChartRange())
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
                loadInitialLogs()
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
    
    private func toggleLogSelection(_ logId: Int) {
        if selectedLogsForComparison.contains(logId) {
            selectedLogsForComparison.remove(logId)
        } else if selectedLogsForComparison.count < 2 {
            selectedLogsForComparison.insert(logId)
        }
    }
    
    private func deleteItems(offsets: IndexSet) {
        let reversedLogs = allLogs.reversed()
        for index in offsets {
            let logToDelete = Array(reversedLogs)[index]
            deleteWeightLog(logToDelete)
        }
    }
    
    private func deleteWeightLog(_ log: WeightLogResponse) {
        NetworkManagerTwo.shared.deleteWeightLog(logId: log.id) { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    print("✅ Weight log deleted successfully via swipe")
                    // Post notification to refresh the weight data view
                    NotificationCenter.default.post(name: Notification.Name("WeightLogDeletedNotification"), object: nil)
                    
                case .failure(let error):
                    print("❌ Error deleting weight log via swipe: \(error)")
                    // TODO: Show error alert to user
                }
            }
        }
    }
    
    // Helper function to format dates
    private func formatDate(_ date: Date, format: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = format
        return formatter.string(from: date)
    }
    
    // Helper function to parse dates robustly
    private func parseDate(_ dateString: String) -> Date? {
        // Try ISO8601 with fractional seconds first
        let iso8601WithFractional = ISO8601DateFormatter()
        iso8601WithFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso8601WithFractional.date(from: dateString) {
            return date
        }
        
        // Try ISO8601 without fractional seconds
        let iso8601 = ISO8601DateFormatter()
        iso8601.formatOptions = [.withInternetDateTime]
        if let date = iso8601.date(from: dateString) {
            return date
        }
        
        // Try other common formats
        let formatters = [
            "yyyy-MM-dd'T'HH:mm:ss.SSSSSSXXXXX",
            "yyyy-MM-dd'T'HH:mm:ss.SSSXXXXX",
            "yyyy-MM-dd'T'HH:mm:ssXXXXX",
            "yyyy-MM-dd'T'HH:mm:ss.SSSSSS'Z'",
            "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'",
            "yyyy-MM-dd'T'HH:mm:ss'Z'"
        ]
        
        for formatString in formatters {
            let formatter = DateFormatter()
            formatter.dateFormat = formatString
            if let date = formatter.date(from: dateString) {
                print("✅ Parsed date '\(dateString)' with format: \(formatString)")
                return date
            }
        }
        
        print("❌ Failed to parse date: '\(dateString)'")
        return nil
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
    
    // Group logs based on timeframe
    private func groupedLogsForChart() -> [ChartDataPoint] {
        guard !logs.isEmpty else { return [] }
        
        var result: [ChartDataPoint] = []
        
        switch timeframe {
        case .week:
            // For week, show individual data points
            for log in logs {
                if let date = parseDate(log.dateLogged) {
                    result.append(ChartDataPoint(
                        date: date, 
                        weightKg: log.weightKg,
                        displayWeight: getDisplayWeight(log.weightKg)
                    ))
                }
            }
            
        case .month, .threeMonths:
            // Group by day
            let calendar = Calendar.current
            var dayGroups: [Date: [Double]] = [:]
            
                                        for log in logs {
                if let date = parseDate(log.dateLogged) {
                    let day = calendar.startOfDay(for: date)
                    if dayGroups[day] == nil {
                        dayGroups[day] = []
                    }
                    dayGroups[day]?.append(log.weightKg)
                }
            }
                
                for (day, weights) in dayGroups {
                    let avgWeightKg = weights.reduce(0, +) / Double(weights.count)
                    result.append(ChartDataPoint(
                        date: day, 
                        weightKg: avgWeightKg,
                        displayWeight: getDisplayWeight(avgWeightKg)
                    ))
                }
            
        case .sixMonths:
            // Group by week
            let calendar = Calendar.current
            var weekGroups: [Date: [Double]] = [:]
            
            for log in logs {
                if let date = parseDate(log.dateLogged) {
                    let weekOfYear = calendar.component(.weekOfYear, from: date)
                    let year = calendar.component(.year, from: date)
                    
                    // Find start of week
                    guard let startOfWeek = calendar.date(from: DateComponents(weekOfYear: weekOfYear, yearForWeekOfYear: year)) else {
                        continue
                    }
                    
                    if weekGroups[startOfWeek] == nil {
                        weekGroups[startOfWeek] = []
                    }
                    weekGroups[startOfWeek]?.append(log.weightKg)
                }
            }
            
            for (week, weights) in weekGroups {
                let avgWeightKg = weights.reduce(0, +) / Double(weights.count)
                result.append(ChartDataPoint(
                    date: week, 
                    weightKg: avgWeightKg,
                    displayWeight: getDisplayWeight(avgWeightKg)
                ))
            }
            
        case .year:
            // Group by month
            let calendar = Calendar.current
            var monthGroups: [Date: [Double]] = [:]
            
            for log in logs {
                if let date = parseDate(log.dateLogged) {
                    let components = calendar.dateComponents([.year, .month], from: date)
                    guard let firstDayOfMonth = calendar.date(from: components) else {
                        continue
                    }
                    
                    if monthGroups[firstDayOfMonth] == nil {
                        monthGroups[firstDayOfMonth] = []
                    }
                    monthGroups[firstDayOfMonth]?.append(log.weightKg)
                }
            }
            
            for (month, weights) in monthGroups {
                let avgWeightKg = weights.reduce(0, +) / Double(weights.count)
                result.append(ChartDataPoint(
                    date: month, 
                    weightKg: avgWeightKg,
                    displayWeight: getDisplayWeight(avgWeightKg)
                ))
            }
        }
        
        // Sort by date
        return result.sorted { $0.date < $1.date }
    }
    
    // Chart data point structure
    struct ChartDataPoint: Identifiable {
        var id: Date { date }
        let date: Date
        let weightKg: Double
        let displayWeight: Double
    }
    
    // Calculate Y-axis range for the chart
    private func weightChartRange() -> ClosedRange<Double> {
        if logs.isEmpty {
            // Default range based on units system
            switch viewModel.unitsSystem {
            case .imperial:
                return 120...180 // lbs
            case .metric:
                return 50...80 // kg
            }
        }
        
        let weights = logs.compactMap { log in
            return getDisplayWeight(log.weightKg)
        }
        
        guard let minWeight = weights.min(), let maxWeight = weights.max() else {
            switch viewModel.unitsSystem {
            case .imperial:
                return 120...180
            case .metric:
                return 50...80
            }
        }
        
        // Add 10% padding above and below
        let padding = (maxWeight - minWeight) * 0.1
        let lowerBound = Swift.max(minWeight - padding, 0)
        let upperBound = maxWeight + padding
        
        // Ensure minimum range based on units system
        let minRange: Double = viewModel.unitsSystem == .imperial ? 10 : 5
        if upperBound - lowerBound < minRange {
            let halfRange = minRange / 2
            return (lowerBound - halfRange)...(upperBound + halfRange)
        }
        
        return lowerBound...upperBound
    }
    
    // Filter logs based on selected timeframe
    private func filterLogs() {
        let cutoff = Calendar.current.date(byAdding: .day, value: -timeframe.days, to: Date()) ?? Date()
        
        logs = allLogs.filter { log in
            if let date = parseDate(log.dateLogged) {
                return date >= cutoff
            }
            return false
        }.sorted { log1, log2 in
            guard let d1 = parseDate(log1.dateLogged),
                  let d2 = parseDate(log2.dateLogged) else { return false }
            return d1 > d2
        }
        
        updateAverageAndDateRange()
    }
    
    // Update current weight display and date range text
    private func updateAverageAndDateRange() {
        // For the current weight, we'll use the most recent entry (first since sorted newest-first)
        if let mostRecentLog = logs.first {
            currentWeight = getDisplayWeight(mostRecentLog.weightKg)
        } else {
            currentWeight = 0
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
    
    // Load initial logs with pagination
    private func loadInitialLogs() {
        // Reset pagination state
        currentPage = 1
        hasMoreLogs = true
        
        // If we have initialAllLogs passed to the view, use them
        if !self.allLogs.isEmpty {
            DispatchQueue.main.async {
                self.filterLogs()
                // Still refresh in background for most up-to-date data
                self.loadMoreLogs(refresh: true)
            }
            return
        }
        
        // Clear existing logs
        allLogs = []
        
        // Clear stale cache to prevent ghost logs
        clearStaleCache()
        
        // Load first page from network (skip cache to get fresh data)
        loadMoreLogs(refresh: true)
    }
    
    // Clear stale cached data to prevent ghost logs
    private func clearStaleCache() {
        guard let userEmail = UserDefaults.standard.string(forKey: "userEmail") else { return }
        
        let userDefaults = UserDefaults.standard
        let allKeys = userDefaults.dictionaryRepresentation().keys
        
        // Remove all weight log caches for this user
        for key in allKeys {
            if key.hasPrefix("weightLogs_\(userEmail)_") {
                userDefaults.removeObject(forKey: key)
            }
        }
    }
    
    // Cache logs to UserDefaults
    private func cacheLogs(_ response: WeightLogsResponse, forPage page: Int) {
        guard let userEmail = UserDefaults.standard.string(forKey: "userEmail") else { return }
        
        if let encodedData = try? JSONEncoder().encode(response) {
            UserDefaults.standard.set(encodedData, forKey: "weightLogs_\(userEmail)_page_\(page)")
        }
    }
    
    // Load more logs with pagination
    private func loadMoreLogs(refresh: Bool = false) {
        guard let email = UserDefaults.standard.string(forKey: "userEmail") else {
            errorMessage = "No user email found. Please sign in again."
            return
        }
        
        // Prevent multiple simultaneous requests
        if isLoadingMore && !refresh { return }
        
        let pageToLoad = refresh ? 1 : currentPage
        
        if refresh {
            isLoading = true
        } else {
            isLoadingMore = true
        }
        
        // Use larger limit for refresh to ensure we get all logs including newly synced ones
        let fetchLimit = refresh ? 100 : pageSize
        let fetchOffset = refresh ? 0 : (pageToLoad - 1) * pageSize
        
        print("🔍 WeightDataView: Fetching logs with limit=\(fetchLimit), offset=\(fetchOffset), refresh=\(refresh)")
        
        NetworkManagerTwo.shared.fetchWeightLogs(
            userEmail: email, 
            limit: fetchLimit, 
            offset: fetchOffset
        ) { result in
            DispatchQueue.main.async {
                if refresh {
                    self.isLoading = false
                } else {
                    self.isLoadingMore = false
                }
                
                switch result {
                case .success(let response):
                    self.errorMessage = nil
                    
                    // DEBUG: Enhanced logging for sync debugging
                    print("🔍 WeightDataView: Received \(response.logs.count) logs from API")
                    print("🔍 WeightDataView: Log IDs received: \(response.logs.map { $0.id })")
                    
                    // Count Apple Health vs manual logs
                    let appleHealthLogs = response.logs.filter { $0.notes?.contains("Apple Health") == true || $0.notes?.contains("Withings") == true }
                    let manualLogs = response.logs.filter { $0.notes?.contains("Apple Health") != true && $0.notes?.contains("Withings") != true }
                    print("🔍 WeightDataView: Apple Health logs: \(appleHealthLogs.count), Manual logs: \(manualLogs.count)")
                    
                    // Cache the response
                    self.cacheLogs(response, forPage: pageToLoad)
                    
                    if refresh {
                        // Replace all logs with new ones (newest first)
                        self.allLogs = response.logs.sorted { log1, log2 in
                            guard let d1 = self.parseDate(log1.dateLogged),
                                  let d2 = self.parseDate(log2.dateLogged) else { return false }
                            return d1 > d2
                        }
                        self.currentPage = 2
                        print("🔍 WeightDataView: After refresh, allLogs count: \(self.allLogs.count)")
                        
                        // Debug: Show first few logs with their details
                        print("🔍 WeightDataView: First 10 logs after refresh:")
                        for (index, log) in self.allLogs.prefix(10).enumerated() {
                            let isAppleHealth = log.notes?.contains("Apple Health") == true || log.notes?.contains("Withings") == true
                            let source = isAppleHealth ? "Apple Health" : "Manual"
                            print("  \(index + 1). ID: \(log.id), Weight: \(log.weightKg)kg, Date: \(log.dateLogged), Source: \(source)")
                        }
                    } else {
                        // Append new logs, avoiding duplicates
                        let newLogs = response.logs.filter { newLog in
                            !self.allLogs.contains { existingLog in
                                existingLog.id == newLog.id
                            }
                        }
                        
                        let sortedNewLogs = newLogs.sorted { log1, log2 in
                            guard let d1 = self.parseDate(log1.dateLogged),
                                  let d2 = self.parseDate(log2.dateLogged) else { return false }
                            return d1 > d2
                        }
                        
                        // Insert older logs at the end (maintaining newest-first order)
                        self.allLogs.append(contentsOf: sortedNewLogs)
                        self.currentPage += 1
                    }
                    
                    // Update hasMoreLogs based on response
                    self.hasMoreLogs = response.logs.count == self.pageSize
                    
                    self.filterLogs()
                    
                case .failure(let error):
                    self.errorMessage = "Failed to load weight data: \(error.localizedDescription)"
                    print("Error fetching weight logs: \(error)")
                }
            }
        }
    }
    
    // Refresh from network (for notifications)
    private func refreshFromNetwork() {
        clearStaleCache()
        loadMoreLogs(refresh: true)
    }
    
    // Pull-to-refresh function (async)
    private func refreshData() async {
        print("🔄 WeightDataView: Pull to refresh triggered")
        
        await MainActor.run {
            clearStaleCache()
            loadMoreLogs(refresh: true)
        }
        
        print("✅ WeightDataView: Pull to refresh completed")
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
    
    // Helper to format sync date
    private func formatSyncDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        if Calendar.current.isDateInToday(date) {
            formatter.dateFormat = "h:mm a"
            return "today at \(formatter.string(from: date))"
        } else if Calendar.current.isDateInYesterday(date) {
            return "yesterday"
        } else {
            formatter.dateFormat = "MMM d"
            return formatter.string(from: date)
        }
    }
}

// MARK: - WeightLogRowView Component
struct WeightLogRowView: View {
    let log: WeightLogResponse
    let date: Date
    let isCompareMode: Bool
    let isSelected: Bool
    let loadedImages: [String: UIImage]
    let onToggleSelection: () -> Void
    let onPhotoTap: (String) -> Void
    let onCameraTap: () -> Void
    let onRowTap: () -> Void
    let onImageLoaded: (String, UIImage) -> Void
    @EnvironmentObject var viewModel: OnboardingViewModel
    
    private func formatWeightDisplay() -> String {
        switch viewModel.unitsSystem {
        case .imperial:
            let displayWeight = log.weightKg * 2.20462
            return "\(String(format: "%.1f", displayWeight)) lbs"
        case .metric:
            return "\(String(format: "%.1f", log.weightKg)) kg"
        }
    }
    
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
            // Selection indicator (only show in compare mode)
            if isCompareMode {
                Button(action: onToggleSelection) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 22))
                        .foregroundColor(isSelected ? .accentColor : .secondary)
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                // Weight in appropriate units with Apple Health indicator
                HStack(spacing: 8) {
                    Text(formatWeightDisplay())
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                    
                    // Show Apple Health indicator if this log came from Apple Health
                    if let notes = log.notes, (notes.contains("Apple Health") || notes.contains("Withings")) {
                        HStack(spacing: 4) {
                            Image(systemName: "heart.text.square")
                                .font(.system(size: 12))
                                .foregroundColor(.pink)
                            Text("Apple Health")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.pink)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.pink.opacity(0.1))
                        .cornerRadius(4)
                    }
                }
                
                Text(formatDateForHistory(date))
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Show photo thumbnail if available, otherwise show camera icon
            if let photoUrl = log.photo, !photoUrl.isEmpty {
                // Photo thumbnail - tap to view full screen
                Button(action: { onPhotoTap(photoUrl) }) {
                    if let cachedImage = loadedImages[photoUrl] {
                        // Use cached image if available
                        Image(uiImage: cachedImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 40, height: 40)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    } else {
                        // Load image asynchronously
                        AsyncImage(url: URL(string: photoUrl)) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .onAppear {
                                        // Convert SwiftUI Image to UIImage for caching
                                        Task {
                                            if let data = try? await URLSession.shared.data(from: URL(string: photoUrl)!).0,
                                               let uiImage = UIImage(data: data) {
                                                DispatchQueue.main.async {
                                                    onImageLoaded(photoUrl, uiImage)
                                                }
                                            }
                                        }
                                    }
                            case .failure(_):
                                Rectangle()
                                    .fill(Color.gray.opacity(0.3))
                                    .overlay(
                                        Image(systemName: "photo")
                                            .foregroundColor(.secondary)
                                    )
                            case .empty:
                                Rectangle()
                                    .fill(Color.gray.opacity(0.3))
                                    .overlay(
                                        ProgressView()
                                            .scaleEffect(0.8)
                                    )
                            @unknown default:
                                Rectangle()
                                    .fill(Color.gray.opacity(0.3))
                            }
                        }
                        .frame(width: 40, height: 40)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
                .buttonStyle(PlainButtonStyle())
                .contentShape(RoundedRectangle(cornerRadius: 8))
            } else {
                // Camera button for weight entries without photos - opens edit view
                Button(action: onCameraTap) {
                    Image(systemName: "camera")
                        .font(.system(size: 20))
                        .foregroundColor(.secondary)
                        .frame(width: 40, height: 40)
                        .background(Color.gray.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(PlainButtonStyle())
                .contentShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .onTapGesture(perform: onRowTap)
        .background(Color(UIColor.systemBackground))
    }
}

#Preview {
    WeightDataView(initialAllLogs: [])
}
