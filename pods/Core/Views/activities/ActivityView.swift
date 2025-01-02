//
//  ActivityView.swift
//  Pods
//
//  Created by Dimi Nunez on 12/26/24.
//

import SwiftUI
import Combine


struct ActivityView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    @StateObject private var activityManager = ActivityManager()
    @Binding var pod: Pod
    @Binding var podColumns: [PodColumn]
    @Binding var items: [PodItem]
    @State private var columnValues: [Int: [String: ColumnValue]] = [:]
    @State private var groupedRowsCounts: [Int: [String: Int]] = [:]
    @State private var expandedColumn: String?
    @FocusState private var focusedField: String?
    @State private var keyboardOffset: CGFloat = 0
    @State private var isCreatingActivity = false
    @EnvironmentObject var viewModel: OnboardingViewModel
    @ObservedObject private var activityState = ActivityState.shared
    @State private var showCancelAlert = false
    let onActivityFinished: (Int, Date, Date) -> Void

    
    private func groupColumns(_ columns: [PodColumn]) -> [[PodColumn]] {
        let groupedColumns = columns.filter { $0.groupingType == "grouped" }
        let singularColumns = columns.filter { $0.groupingType == "singular" }
        return [groupedColumns, singularColumns].filter { !$0.isEmpty }
    }
    
    private var keyboardPublisher: AnyPublisher<CGFloat, Never> {
        Publishers.Merge(
            NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)
                .map { $0.keyboardHeight },
            NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)
                .map { _ in CGFloat(0) }
        )
        .eraseToAnyPublisher()
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color("iosbg")
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header with timer
                    
                    if activityState.sheetHeight == .height(50) {
                        MinimizedActivityView(podTitle: pod.title, onDismiss: { self.dismiss() })
                         
                    } else {
                        HStack {
                            Image(systemName: "timer")
                                .font(.system(size: 18))
                                .foregroundColor(.primary)
                                .frame(width: 60)
                            
                            Spacer()
                            
                            Text(activityState.stopwatch.formattedTime)
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            Button(action: handleFinish) {
                                Text("Finish")
                                    .fontWeight(.medium)
                                    .font(.system(size: 18))
                                    .foregroundColor(Color("iosred"))
                                    .frame(width: 60)
                            }
                        }
                        .padding()
                    }
              
                    ScrollViewReader { proxy in
                        ScrollView {
                  
                            // Pod Title
                            Text(pod.title)
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal)
                            
                            
                            VStack(spacing: 20) {
                                ForEach(items) { item in
                                    VStack(alignment: .leading, spacing: 15) {
                                        Text(item.metadata)
                                            .font(.system(size: 18))
                                            .fontDesign(.rounded)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.accentColor)
                                        
                                        let columnGroups = groupColumns(podColumns)
                                        ForEach(Array(columnGroups.indices), id: \.self) { groupIndex in
                                            let columnGroup = columnGroups[groupIndex]
                                            
                                            if columnGroup.first?.groupingType == "singular" {
                                                ForEach(columnGroup, id: \.id) { column in
                                                    VStack(alignment: .leading, spacing: 5) {
                                                        SingularColumnActivityView(
                                                            itemId: item.id,
                                                            column: column,
                                                            columnValues: bindingForItem(item.id),
                                                            focusedField: $focusedField,
                                                            expandedColumn: $expandedColumn,
                                                            onValueChanged: { }
                                                        )
                                                    }
                                                }
                                            } else {
                                                
                                                GroupedColumnActivityView(
                                                    itemId: item.id,
                                                    columnGroup: columnGroup,
                                                    groupedRowsCount: groupedRowsCounts[item.id]?[columnGroup.first?.groupingType ?? ""] ?? 1,
                                                    onAddRow: { addRow(for: columnGroup, itemId: item.id) },
                                                    onDeleteRow: { idx in deleteRow(at: idx, in: columnGroup, itemId: item.id) },
                                                    columnValues: bindingForItem(item.id),
                                                    focusedField: $focusedField,
                                                    expandedColumn: $expandedColumn,
                                                    onValueChanged: { }
                                                )
                                                
                                            }
                                        }
                                    }
                                    .padding()
                                    
                                }
                            }
                            
                            Button(action: onCancelActivity) {
                                Text("Cancel Activity")
                                    .font(.system(size: 16))
                                    .fontWeight(.medium)
                                    .foregroundColor(Color("iosred"))
                                    .frame(maxWidth: .infinity)  // Move frame here
                                    .padding(.vertical, 12)
                                    .background(Color("iosred").opacity(0.1))  // Move background here
                                    .cornerRadius(8)
                            }
                            .padding(.horizontal)
                            .padding(.bottom, 40)
                            
                            Spacer()
                                .frame(height: keyboardOffset)
                            
                                                    }
                                                }
                       
                }
            }
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Button("Clear") {
                        clearFocusedField()
                    }
                    .foregroundColor(.accentColor)
                    
                    Spacer()
                    
                    Button("Done") {
                        hideKeyboard()
                    }
                    .foregroundColor(.accentColor)
                    .fontWeight(.medium)
                }
            }
        }
        .navigationBarHidden(true)
        
        .onAppear {
            initializeColumnValues()
            print("Initializing ActivityManager with podId: \(pod.id), email: \(viewModel.email)")
            activityManager.initialize(podId: pod.id, userEmail: viewModel.email)
            
            if activityState.stopwatch.elapsedTime == 0 {
                activityState.stopwatch.start()
            }
            activityState.isActivityInProgress = true
        }
      
    
        
        
    }

private func onCancelActivity() {
    activityState.cancelActivity()
    
    dismiss()
}

    
    private func convertColumnValueToAny(_ value: ColumnValue) -> Any {
            switch value {
            case .number(let num):
                return num
            case .string(let str):
                return str
            case .time(let timeValue):
                return timeValue.toString
            case .array(let values):
                return values.map { convertColumnValueToAny($0) }
            case .null:
                return NSNull()
            }
        }
    
    private func handleFinish() {
        guard !isCreatingActivity else { return }
        isCreatingActivity = true
        
        let endTime = Date()
        let startTime = endTime.addingTimeInterval(-activityState.stopwatch.elapsedTime)
        let duration = Int(activityState.stopwatch.elapsedTime)
        
        print("Preparing to create activity...")
        
        // Prepare items data
        let itemsData: [(id: Int, notes: String?, columnValues: [String: Any])] = items.map { item in
            let values = columnValues[item.id] ?? [:]
            let convertedValues = values.mapValues { value in
                convertColumnValueToAny(value)
            }
            return (
                id: item.id,
                notes: nil,
                columnValues: convertedValues
            )
        }
        
        // Create activity
        activityManager.createActivity(
            duration: Int(activityState.stopwatch.elapsedTime),
            notes: nil,
            items: itemsData
        )
        
        // Update each item's columnValues
        for (index, item) in items.enumerated() {
            if let values = columnValues[item.id] {
                items[index].columnValues = values
            }
        }
        
        
        onActivityFinished(duration, startTime, endTime)
        activityState.finishActivity()
       
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            
            print("Activity creation initiated, dismissing view...")
            self.isCreatingActivity = false
            self.dismiss()
        }
    }

    
    private func clearFocusedField() {
        guard let fieldID = focusedField else { return }
        let parts = fieldID.split(separator: "_").map(String.init)
        guard parts.count >= 2 else { return }
        
        let itemId = Int(parts[0]) ?? 0
        let columnId = parts[1]
        
        if parts.count == 3, let rowIndex = Int(parts[2]) {
            // grouped
            if var val = columnValues[itemId]?[columnId],
               case .array(var arr) = val, rowIndex < arr.count {
                arr[rowIndex] = .null
                columnValues[itemId]?[columnId] = .array(arr)
            }
        } else {
            // singular
            columnValues[itemId]?[columnId] = .null
        }
    }

    
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
 

 
    private func bindingForItem(_ itemId: Int) -> Binding<[String: ColumnValue]> {
        Binding(
            get: { columnValues[itemId] ?? [:] },
            set: { columnValues[itemId] = $0 }
        )
    }
    
    func initializeColumnValues() {
        for item in items {
            columnValues[item.id] = item.columnValues ?? [:]
            
            var rowCounts: [String: Int] = [:]
            for column in podColumns where column.groupingType == "grouped" {
                if let values = item.columnValues?[String(column.id)],
                   case .array(let array) = values {
                    rowCounts[column.groupingType ?? ""] = array.count
                } else {
                    rowCounts[column.groupingType ?? ""] = 0
                }
            }
            groupedRowsCounts[item.id] = rowCounts
        }
    }
    
    private func addRow(for columnGroup: [PodColumn], itemId: Int) {
        let groupType = columnGroup.first?.groupingType ?? ""
        let currentRowIndex = groupedRowsCounts[itemId]?[groupType] ?? 1
        
        for column in columnGroup {
            let currentValue = columnValues[itemId]?[String(column.id)] ?? .array([])
            var values: [ColumnValue] = []
            
            if case .array(let existingValues) = currentValue {
                values = existingValues
            }
            
            if column.type == "number" {
                if case .number(1.0) = values.first {
                    values.append(.number(Double(values.count + 1)))
                } else {
                    values.append(values.last ?? .null)
                }
            } else {
                values.append(values.last ?? .null)
            }
            
            columnValues[itemId]?[String(column.id)] = .array(values)
        }
        
        groupedRowsCounts[itemId]?[groupType] = currentRowIndex + 1
    }
    
    private func deleteRow(at index: Int, in columnGroup: [PodColumn], itemId: Int) {
        for column in columnGroup {
            if var values = columnValues[itemId]?[String(column.id)],
               case .array(var array) = values,
               index < array.count {
                array.remove(at: index)
                columnValues[itemId]?[String(column.id)] = .array(array)
            }
        }
        
        let groupType = columnGroup.first?.groupingType ?? ""
        if let currentCount = groupedRowsCounts[itemId]?[groupType],
           currentCount > 0 {
            groupedRowsCounts[itemId]?[groupType] = currentCount - 1
        }
    }
}

class Stopwatch: ObservableObject {
    @Published var elapsedTime: TimeInterval = 0
    private var startDate: Date?
    private var timer: Timer?
    
    var formattedTime: String {
        let hours = Int(elapsedTime) / 3600
        let minutes = Int(elapsedTime) / 60 % 60
        let seconds = Int(elapsedTime) % 60
        return String(format: "%d:%02d:%02d", hours, minutes, seconds)
    }
    
    init() {
        // Add observers for app lifecycle
        NotificationCenter.default.addObserver(self,
            selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(self,
            selector: #selector(appWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
    }
    
    func start() {
        startDate = Date().addingTimeInterval(-elapsedTime)
        scheduleTimer()
    }
    
    private func scheduleTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self = self, let startDate = self.startDate else { return }
            self.elapsedTime = Date().timeIntervalSince(startDate)
        }
    }
    
    @objc private func appDidEnterBackground() {
        timer?.invalidate()
        // Store current timestamp
        if let startDate = startDate {
            UserDefaults.standard.set(startDate.timeIntervalSince1970, forKey: "stopwatch_start_time")
        }
    }
    
    @objc private func appWillEnterForeground() {
        if let storedStartTime = UserDefaults.standard.object(forKey: "stopwatch_start_time") as? TimeInterval {
            startDate = Date(timeIntervalSince1970: storedStartTime)
            scheduleTimer()
        }
    }
    
    func stop() {
        timer?.invalidate()
        timer = nil
        startDate = nil
        UserDefaults.standard.removeObject(forKey: "stopwatch_start_time")
    }
    
    func reset() {
        stop()
        elapsedTime = 0
    }
    
    deinit {
        stop()
        NotificationCenter.default.removeObserver(self)
    }
}

class ActivityState: ObservableObject {
    @Published var stopwatch: Stopwatch
    @Published var isActivityInProgress = false
    @Published var sheetHeight: PresentationDetent = .large  // Start with large

    static let shared = ActivityState()
    
    private init() {
        self.stopwatch = Stopwatch()
        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                self?.objectWillChange.send()
            }
        }
    }
    
    func startActivity() {
        isActivityInProgress = true
        sheetHeight = .large  // Ensure full screen when starting
        stopwatch.start()
    }
    
    func cancelActivity() {
        isActivityInProgress = false
        stopwatch.stop()
        stopwatch.reset()
    }
    
    func finishActivity() {
        isActivityInProgress = false
        sheetHeight = .large
        stopwatch.stop()
        stopwatch.reset()
    }
    
    func minimize() {
        if isActivityInProgress {
            sheetHeight = .height(60)
        }
    }
}


extension Notification {
    var keyboardHeight: CGFloat {
        (userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect)?.height ?? 0
    }
}
