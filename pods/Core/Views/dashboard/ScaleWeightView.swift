//
//  ScaleWeightView.swift
//  pods
//
//  Created by Dimi Nunez on 12/28/25.
//

import SwiftUI
import Charts

// MARK: - WeightTimeRange Enum

enum WeightTimeRange: String, CaseIterable {
    case day = "D"
    case week = "W"
    case month = "M"
    case sixMonths = "6M"
    case year = "Y"

    var displayName: String {
        switch self {
        case .day: return "Today"
        case .week: return "This Week"
        case .month: return "This Month"
        case .sixMonths: return "6 Months"
        case .year: return "This Year"
        }
    }

    func startDate(from now: Date = Date()) -> Date {
        let calendar = Calendar.current
        switch self {
        case .day:
            return calendar.startOfDay(for: now)
        case .week:
            return calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)) ?? now
        case .month:
            return calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now
        case .sixMonths:
            return calendar.date(byAdding: .month, value: -6, to: now) ?? now
        case .year:
            return calendar.date(from: calendar.dateComponents([.year], from: now)) ?? now
        }
    }
}

// MARK: - ScaleWeightViewModel

@MainActor
class ScaleWeightViewModel: ObservableObject {
    @Published var allLogs: [WeightLogResponse] = []
    @Published var selectedRange: WeightTimeRange = .month
    @Published var isLoading = false
    @Published var errorMessage: String? = nil

    private var hasMoreLogs = true
    private var currentPage = 1
    private let pageSize = 100

    // MARK: - Computed Properties

    var filteredLogs: [WeightLogResponse] {
        let startDate = selectedRange.startDate()
        let now = Date()

        return allLogs.filter { log in
            guard let date = parseDate(log.dateLogged) else { return false }
            return date >= startDate && date <= now
        }.sorted { log1, log2 in
            guard let d1 = parseDate(log1.dateLogged),
                  let d2 = parseDate(log2.dateLogged) else { return false }
            return d1 > d2  // Most recent first
        }
    }

    /// Most recent weight log overall (not filtered)
    var currentWeight: Double? {
        guard let mostRecent = allLogs.sorted(by: { log1, log2 in
            guard let d1 = parseDate(log1.dateLogged),
                  let d2 = parseDate(log2.dateLogged) else { return false }
            return d1 > d2
        }).first else { return nil }
        return mostRecent.weightKg
    }

    /// Average weight in the filtered range
    var averageWeight: Double? {
        guard !filteredLogs.isEmpty else { return nil }
        let sum = filteredLogs.reduce(0.0) { $0 + $1.weightKg }
        return sum / Double(filteredLogs.count)
    }

    /// Delta: current weight - earliest weight in filtered range
    var deltaWeight: Double? {
        guard let current = currentWeight,
              filteredLogs.count >= 2 else { return nil }

        // Get earliest log in filtered range (last in descending sorted list)
        guard let earliest = filteredLogs.last else { return nil }
        return current - earliest.weightKg
    }

    /// Group logs by month for section display
    var groupedLogs: [(key: String, logs: [WeightLogResponse])] {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"

        var groups: [String: [WeightLogResponse]] = [:]
        var groupOrder: [String] = []

        for log in filteredLogs {
            guard let date = parseDate(log.dateLogged) else { continue }
            let key = formatter.string(from: date)

            if groups[key] == nil {
                groups[key] = []
                groupOrder.append(key)
            }
            groups[key]?.append(log)
        }

        return groupOrder.map { key in
            (key: key, logs: groups[key] ?? [])
        }
    }

    // MARK: - Date Parsing

    func parseDate(_ dateString: String) -> Date? {
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
            formatter.locale = Locale(identifier: "en_US_POSIX")
            if let date = formatter.date(from: dateString) {
                return date
            }
        }

        return nil
    }

    // MARK: - Data Loading

    func loadLogs() {
        guard let email = UserDefaults.standard.string(forKey: "userEmail") else {
            errorMessage = "No user email found. Please sign in again."
            return
        }

        isLoading = true
        errorMessage = nil
        currentPage = 1

        NetworkManagerTwo.shared.fetchWeightLogs(
            userEmail: email,
            limit: pageSize,
            offset: 0
        ) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isLoading = false

                switch result {
                case .success(let response):
                    self.allLogs = response.logs.sorted { log1, log2 in
                        guard let d1 = self.parseDate(log1.dateLogged),
                              let d2 = self.parseDate(log2.dateLogged) else { return false }
                        return d1 > d2
                    }
                    self.hasMoreLogs = response.logs.count == self.pageSize
                    self.currentPage = 2

                case .failure(let error):
                    self.errorMessage = "Failed to load weight data: \(error.localizedDescription)"
                }
            }
        }
    }

    func refreshLogs() {
        loadLogs()
    }

    func deleteLog(_ log: WeightLogResponse) {
        NetworkManagerTwo.shared.deleteWeightLog(logId: log.id) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self?.allLogs.removeAll { $0.id == log.id }
                    NotificationCenter.default.post(
                        name: Notification.Name("WeightLogDeletedNotification"),
                        object: nil
                    )
                case .failure(let error):
                    print("Error deleting weight log: \(error)")
                }
            }
        }
    }
}

// MARK: - ScaleWeightView

struct ScaleWeightView: View {
    @StateObject private var viewModel = ScaleWeightViewModel()
    @EnvironmentObject var onboardingViewModel: OnboardingViewModel
    @Environment(\.isTabBarVisible) private var isTabBarVisible

    // UI State
    @State private var showingEditSheet = false
    @State private var selectedLogForEdit: WeightLogResponse? = nil
    @State private var showingFullScreenPhoto = false
    @State private var fullScreenPhotoUrl: String = ""
    @State private var fullScreenImage: UIImage? = nil
    @State private var loadedImages: [String: UIImage] = [:]

    // Compare Mode
    @State private var isCompareMode = false
    @State private var selectedLogsForComparison: Set<Int> = []
    @State private var showingCompareView = false

    // Chart Selection
    @State private var selectedDataPoint: ScaleChartDataPoint? = nil
    @State private var isChartTapped = false

    // MARK: - Unit Helpers

    private var weightUnit: String {
        switch onboardingViewModel.unitsSystem {
        case .imperial: return "lbs"
        case .metric: return "kg"
        }
    }

    private func formatWeight(_ weightKg: Double) -> String {
        let displayWeight = getDisplayWeight(weightKg)
        return String(format: "%.1f", displayWeight)
    }

    private func getDisplayWeight(_ weightKg: Double) -> Double {
        switch onboardingViewModel.unitsSystem {
        case .imperial: return weightKg * 2.20462
        case .metric: return weightKg
        }
    }

    // MARK: - Body

    var body: some View {
        List {
            // Header section
            Section {
                timeRangePicker
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)

                statsRow
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)

                if let error = viewModel.errorMessage {
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

            // History sections grouped by month
            if !viewModel.filteredLogs.isEmpty && viewModel.errorMessage == nil {
                // History header with compare button
                Section {
                    HStack {
                        Text("History")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)

                        Spacer()

                        compareButton
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }

                // Grouped log sections
                ForEach(viewModel.groupedLogs, id: \.key) { group in
                    Section {
                        // Section header
                        Text(group.key)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)
                            .padding(.horizontal)
                            .padding(.top, 16)
                            .padding(.bottom, 4)
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)

                        // Logs in this section
                        ForEach(group.logs, id: \.id) { log in
                            if let date = viewModel.parseDate(log.dateLogged) {
                                logRowView(log: log, date: date)
                                    .listRowInsets(EdgeInsets())
                                    .listRowBackground(Color.clear)
                                    .listRowSeparator(.hidden)
                            }
                        }
                        .onDelete { indexSet in
                            deleteLogsInGroup(group: group, at: indexSet)
                        }
                    }
                }
            }
        }
        .listStyle(PlainListStyle())
        .scrollContentBackground(.hidden)
        .environment(\.defaultMinListRowHeight, 0)
        .refreshable {
            viewModel.refreshLogs()
        }
        .safeAreaInset(edge: .bottom) {
            if isCompareMode {
                compareFooter
            }
        }
        .navigationTitle("Weight")
        .navigationBarItems(trailing: Button("Add Data") {
            showingEditSheet = true
        })
        .onAppear {
            viewModel.loadLogs()
            isTabBarVisible.wrappedValue = false
        }
        .onDisappear {
            isTabBarVisible.wrappedValue = true
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("WeightLoggedNotification")).receive(on: RunLoop.main)) { _ in
            viewModel.refreshLogs()
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("WeightLogDeletedNotification")).receive(on: RunLoop.main)) { _ in
            viewModel.refreshLogs()
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("WeightLogUpdatedNotification")).receive(on: RunLoop.main)) { _ in
            viewModel.refreshLogs()
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("AppleHealthWeightSynced")).receive(on: RunLoop.main)) { _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                viewModel.refreshLogs()
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            EditWeightView()
        }
        .sheet(item: $selectedLogForEdit) { log in
            UpdateEditWeightView(weightLog: log)
        }
        .sheet(isPresented: $showingCompareView) {
            let selectedLogs = viewModel.allLogs.filter { selectedLogsForComparison.contains($0.id) }
            CompareWeightLogsView(selectedLogs: selectedLogs)
        }
        .fullScreenCover(isPresented: $showingFullScreenPhoto) {
            if !fullScreenPhotoUrl.isEmpty {
                FullScreenPhotoView(photoUrl: fullScreenPhotoUrl)
            } else if let image = fullScreenImage {
                FullScreenPhotoView(preloadedImage: image)
            }
        }
    }

    // MARK: - Time Range Picker

    private var timeRangePicker: some View {
        Picker("Time Range", selection: $viewModel.selectedRange) {
            ForEach(WeightTimeRange.allCases, id: \.self) { range in
                Text(range.rawValue).tag(range)
            }
        }
        .pickerStyle(SegmentedPickerStyle())
        .padding(.horizontal)
        .padding(.top, 8)
    }

    // MARK: - Stats Row

    private var statsRow: some View {
        HStack(spacing: 0) {
            // Average
            VStack(alignment: .leading, spacing: 4) {
                Text("AVG")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)

                if let avg = viewModel.averageWeight {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(formatWeight(avg))
                            .font(.system(size: 24, weight: .semibold, design: .rounded))
                        Text(weightUnit)
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                } else {
                    Text("—")
                        .font(.system(size: 24, weight: .semibold, design: .rounded))
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Delta
            VStack(alignment: .trailing, spacing: 4) {
                Text("CHANGE")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)

                if let delta = viewModel.deltaWeight {
                    let displayDelta = getDisplayWeight(delta)
                    let sign = displayDelta >= 0 ? "+" : ""

                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(sign)\(String(format: "%.1f", displayDelta))")
                            .font(.system(size: 24, weight: .semibold, design: .rounded))
                            .foregroundColor(.primary)
                        Text(weightUnit)
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                } else {
                    Text("—")
                        .font(.system(size: 24, weight: .semibold, design: .rounded))
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal)
        .padding(.vertical, 16)
    }

    // MARK: - Chart View

    private var chartView: some View {
        Group {
            if viewModel.isLoading {
                ProgressView()
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .center)
            } else if viewModel.filteredLogs.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary.opacity(0.5))
                    Text("No data for this time period")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(height: 200)
                .frame(maxWidth: .infinity)
            } else {
                weightChart
            }
        }
    }

    private var weightChart: some View {
        Chart {
            ForEach(chartDataPoints, id: \.date) { dataPoint in
                LineMark(
                    x: .value("Date", dataPoint.date),
                    y: .value("Weight", dataPoint.displayWeight)
                )
                .lineStyle(StrokeStyle(lineWidth: 2))
                .foregroundStyle(Color.indigo)

                // Background point to mask line
                PointMark(
                    x: .value("Date", dataPoint.date),
                    y: .value("Weight", dataPoint.displayWeight)
                )
                .symbol(.circle)
                .symbolSize(CGSize(width: 12, height: 12))
                .foregroundStyle(Color(UIColor.systemBackground))

                // Outlined hollow point
                PointMark(
                    x: .value("Date", dataPoint.date),
                    y: .value("Weight", dataPoint.displayWeight)
                )
                .symbol(.circle.strokeBorder(lineWidth: 2))
                .symbolSize(CGSize(width: 10, height: 10))
                .foregroundStyle(Color.indigo)
            }

            // Selected point annotation
            if let selectedPoint = selectedDataPoint, isChartTapped {
                RuleMark(x: .value("Selected Date", selectedPoint.date))
                    .foregroundStyle(Color.gray.opacity(0.7))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))

                PointMark(
                    x: .value("Selected Date", selectedPoint.date),
                    y: .value("Selected Weight", selectedPoint.displayWeight)
                )
                .symbolSize(CGSize(width: 14, height: 14))
                .foregroundStyle(Color.indigo)
                .annotation(position: .top) {
                    VStack(alignment: .center, spacing: 4) {
                        Text("\(String(format: "%.1f", selectedPoint.displayWeight)) \(weightUnit)")
                            .font(.headline)
                            .foregroundColor(.primary)
                        Text(formatDateForChart(selectedPoint.date))
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
        .chartYScale(domain: chartYRange)
        .chartXAxis {
            AxisMarks { value in
                if let date = value.as(Date.self) {
                    AxisGridLine()
                    AxisValueLabel {
                        Text(xAxisLabel(for: date))
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
        .frame(height: 280)
        .padding()
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    findClosestDataPoint(at: value.location)
                    isChartTapped = true
                }
                .onEnded { _ in }
        )
        .onTapGesture {
            isChartTapped = false
            selectedDataPoint = nil
        }
    }

    private var chartDataPoints: [ScaleChartDataPoint] {
        var result: [ScaleChartDataPoint] = []

        switch viewModel.selectedRange {
        case .day, .week, .month:
            // Show individual data points (actual values, not averages)
            for log in viewModel.filteredLogs {
                if let date = viewModel.parseDate(log.dateLogged) {
                    result.append(ScaleChartDataPoint(
                        date: date,
                        weightKg: log.weightKg,
                        displayWeight: getDisplayWeight(log.weightKg)
                    ))
                }
            }

        case .sixMonths:
            // Group by week
            let calendar = Calendar.current
            var weekGroups: [Date: [Double]] = [:]

            for log in viewModel.filteredLogs {
                if let date = viewModel.parseDate(log.dateLogged) {
                    let weekOfYear = calendar.component(.weekOfYear, from: date)
                    let year = calendar.component(.year, from: date)

                    if let startOfWeek = calendar.date(from: DateComponents(weekOfYear: weekOfYear, yearForWeekOfYear: year)) {
                        if weekGroups[startOfWeek] == nil {
                            weekGroups[startOfWeek] = []
                        }
                        weekGroups[startOfWeek]?.append(log.weightKg)
                    }
                }
            }

            for (week, weights) in weekGroups {
                let avgWeight = weights.reduce(0, +) / Double(weights.count)
                result.append(ScaleChartDataPoint(
                    date: week,
                    weightKg: avgWeight,
                    displayWeight: getDisplayWeight(avgWeight)
                ))
            }

        case .year:
            // Group by month
            let calendar = Calendar.current
            var monthGroups: [Date: [Double]] = [:]

            for log in viewModel.filteredLogs {
                if let date = viewModel.parseDate(log.dateLogged) {
                    let components = calendar.dateComponents([.year, .month], from: date)
                    if let firstDayOfMonth = calendar.date(from: components) {
                        if monthGroups[firstDayOfMonth] == nil {
                            monthGroups[firstDayOfMonth] = []
                        }
                        monthGroups[firstDayOfMonth]?.append(log.weightKg)
                    }
                }
            }

            for (month, weights) in monthGroups {
                let avgWeight = weights.reduce(0, +) / Double(weights.count)
                result.append(ScaleChartDataPoint(
                    date: month,
                    weightKg: avgWeight,
                    displayWeight: getDisplayWeight(avgWeight)
                ))
            }
        }

        return result.sorted { $0.date < $1.date }
    }

    private var chartYRange: ClosedRange<Double> {
        let weights = chartDataPoints.map { $0.displayWeight }

        guard let minWeight = weights.min(), let maxWeight = weights.max() else {
            return onboardingViewModel.unitsSystem == .imperial ? 120...180 : 50...80
        }

        let padding = max((maxWeight - minWeight) * 0.1, onboardingViewModel.unitsSystem == .imperial ? 5 : 2)
        let lowerBound = Swift.max(minWeight - padding, 0)
        let upperBound = maxWeight + padding

        return lowerBound...upperBound
    }

    private func xAxisLabel(for date: Date) -> String {
        let formatter = DateFormatter()
        switch viewModel.selectedRange {
        case .day:
            formatter.dateFormat = "ha"
        case .week:
            formatter.dateFormat = "EEE"
        case .month:
            formatter.dateFormat = "d"
        case .sixMonths, .year:
            formatter.dateFormat = "MMM"
        }
        return formatter.string(from: date)
    }

    private func formatDateForChart(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: date)
    }

    private func findClosestDataPoint(at location: CGPoint) {
        let chartWidth: CGFloat = UIScreen.main.bounds.width - 32
        let dataPoints = chartDataPoints
        guard !dataPoints.isEmpty else { return }

        guard let startDate = dataPoints.first?.date,
              let endDate = dataPoints.last?.date else { return }

        let totalTimeInterval = endDate.timeIntervalSince(startDate)
        guard totalTimeInterval > 0 else {
            selectedDataPoint = dataPoints.first
            return
        }

        let xRatio = min(max(location.x / chartWidth, 0), 1)
        let estimatedDate = startDate.addingTimeInterval(totalTimeInterval * Double(xRatio))

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

    // MARK: - Compare Mode

    private var compareButton: some View {
        Button(action: {
            if isCompareMode {
                isCompareMode = false
                selectedLogsForComparison.removeAll()
            } else {
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

    // MARK: - Log Row View

    private func logRowView(log: WeightLogResponse, date: Date) -> some View {
        VStack(spacing: 0) {
            HStack {
                // Selection indicator (compare mode)
                if isCompareMode {
                    Button(action: { toggleLogSelection(log.id) }) {
                        Image(systemName: selectedLogsForComparison.contains(log.id) ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 22))
                            .foregroundColor(selectedLogsForComparison.contains(log.id) ? .accentColor : .secondary)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("\(formatWeight(log.weightKg)) \(weightUnit)")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)

                    Text(formatDateForRow(date))
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Photo thumbnail or camera button
                if let photoUrl = log.photo, !photoUrl.isEmpty {
                    Button(action: {
                        if let cachedImage = loadedImages[photoUrl] {
                            fullScreenImage = cachedImage
                            fullScreenPhotoUrl = ""
                        } else {
                            fullScreenPhotoUrl = photoUrl
                            fullScreenImage = nil
                        }
                        showingFullScreenPhoto = true
                    }) {
                        if let cachedImage = loadedImages[photoUrl] {
                            Image(uiImage: cachedImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 40, height: 40)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        } else {
                            AsyncImage(url: URL(string: photoUrl)) { phase in
                                switch phase {
                                case .success(let image):
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .onAppear {
                                            Task {
                                                if let data = try? await URLSession.shared.data(from: URL(string: photoUrl)!).0,
                                                   let uiImage = UIImage(data: data) {
                                                    await MainActor.run {
                                                        loadedImages[photoUrl] = uiImage
                                                    }
                                                }
                                            }
                                        }
                                case .failure:
                                    Rectangle()
                                        .fill(Color.gray.opacity(0.3))
                                        .overlay(
                                            Image(systemName: "photo")
                                                .foregroundColor(.secondary)
                                        )
                                case .empty:
                                    Rectangle()
                                        .fill(Color.gray.opacity(0.3))
                                        .overlay(ProgressView().scaleEffect(0.8))
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
                } else {
                    Button(action: { selectedLogForEdit = log }) {
                        Image(systemName: "camera")
                            .font(.system(size: 20))
                            .foregroundColor(.secondary)
                            .frame(width: 40, height: 40)
                            .background(Color.gray.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
            .onTapGesture {
                if isCompareMode {
                    toggleLogSelection(log.id)
                } else {
                    selectedLogForEdit = log
                }
            }
            .background(Color(UIColor.systemBackground))

            Divider()
                .padding(.leading, 16)
        }
    }

    private func formatDateForRow(_ date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()

        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else if let daysAgo = calendar.dateComponents([.day], from: date, to: now).day, daysAgo <= 7 {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE"
            return formatter.string(from: date)
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d, yyyy"
            return formatter.string(from: date)
        }
    }

    private func toggleLogSelection(_ logId: Int) {
        if selectedLogsForComparison.contains(logId) {
            selectedLogsForComparison.remove(logId)
        } else if selectedLogsForComparison.count < 2 {
            selectedLogsForComparison.insert(logId)
        }
    }

    private func deleteLogsInGroup(group: (key: String, logs: [WeightLogResponse]), at offsets: IndexSet) {
        for index in offsets {
            let log = group.logs[index]
            viewModel.deleteLog(log)
        }
    }

    // MARK: - Error View

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
                viewModel.loadLogs()
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
}

// MARK: - Chart Data Point

struct ScaleChartDataPoint: Identifiable {
    var id: Date { date }
    let date: Date
    let weightKg: Double
    let displayWeight: Double
}

// MARK: - Preview

#Preview {
    NavigationView {
        ScaleWeightView()
            .environmentObject(OnboardingViewModel())
    }
}
