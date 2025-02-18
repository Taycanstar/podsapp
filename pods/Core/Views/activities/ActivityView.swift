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
//    @ObservedObject var activityManager: ActivityManager
    @EnvironmentObject var activityManager: ActivityManager
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
    let onActivityFinished: (Int, Date, Date, String?) -> Void
    @State private var showNotesInput = false
    @State private var activityNotes: String = ""

    
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
                            
                            if !showNotesInput {
                                Button(action: {
                                    showNotesInput = true
                                }) {
                                    Text("Add Notes")
                                        .font(.system(size: 16))
                                        .fontWeight(.medium)
                                        .foregroundColor(.accentColor)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                        .background(Color.accentColor.opacity(0.1))
                                        .cornerRadius(8)
                                }
                                .padding(.horizontal)
                                .opacity(showNotesInput ? 0 : 1)
                                .animation(.easeInOut, value: showNotesInput)

                            }
                
                            if showNotesInput {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Notes")
                                        .font(.system(size: 18))
                                        .fontDesign(.rounded)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.accentColor)
                                    
                                    TextField("", text: $activityNotes, axis: .vertical)
                                        .textFieldStyle(.plain)
                                        .padding()
                                        .background(Color("iosnp"))
                                        .cornerRadius(12)
                                }
                                .padding(.horizontal)
                                .padding(.bottom)
                                .transition(.opacity)
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
    
    // Update local items with the latest columnValues from the temporary state
    for index in items.indices {
        items[index].columnValues = columnValues[items[index].id] ?? [:]
    }
    
    // Write back the updated items into the bound pod so the global state reflects the deletions/changes.
    pod.items = items

    print("Preparing to create activity...")
    
    // Prepare items data for the backend using the updated items
    let itemsData = items.compactMap { item -> (id: Int, notes: String?, columnValues: [String: Any])? in
        let itemColumnValues = columnValues[item.id] ?? [:]
        // Check if this item has any valid (non-null/non-empty) values
        let hasValidValues = itemColumnValues.values.contains { value in
            switch value {
            case .null:
                return false
            case .array(let arr):
                return !arr.isEmpty
            default:
                return true
            }
        }
        
        // if itemColumnValues.isEmpty || !hasValidValues {
        //     return nil
        // }
        return (id: item.id, notes: nil, columnValues: itemColumnValues.mapValues { convertColumnValueToAny($0) })
    }
    
    // Step 1: Create a temporary activity with a unique negative temporary ID
    let tempId = Int.random(in: Int.min ... -1)
    let tempActivity = Activity(
        id: tempId,
        podId: pod.id,
        podTitle: pod.title,
        userEmail: viewModel.email,
        userName: viewModel.username,
        duration: duration,
        loggedAt: startTime,
        notes: activityNotes.isEmpty ? nil : activityNotes,
        isSingleItem: false,
        items: itemsData.compactMap { item -> ActivityItem? in
            guard !item.columnValues.isEmpty else { return nil }
            return ActivityItem(
                id: Int.random(in: Int.min ... -1),
                activityId: tempId,
                itemId: item.id,
                itemLabel: items.first(where: { $0.id == item.id })?.metadata ?? "",
                loggedAt: startTime,
                notes: item.notes,
                columnValues: item.columnValues.mapValues { value in
                    if let array = value as? [Double], !array.isEmpty {
                        return .array(array.map { .number($0) })
                    } else if let number = value as? Double {
                        return .number(number)
                    }
                    return .null
                }
            )
        }
    )
    
    // Step 2: Insert the temporary activity into ActivityManager's activities array
    activityManager.activities.insert(tempActivity, at: 0)
    print("Inserted temporary activity with ID: \(tempId)")
    
    // Step 3: Dismiss ActivityView immediately so that the temporary activity appears in the log
    dismiss()
    print("Dismissed ActivityView to show temporary activity.")
    
    // Step 4: Navigate to ActivitySummaryView by calling onActivityFinished
    onActivityFinished(duration, startTime, endTime, activityNotes.isEmpty ? nil : activityNotes)
    print("Called onActivityFinished to navigate to ActivitySummaryView.")

    print("Column values before creating activity:", columnValues)
    print("Items data being sent to backend:", itemsData)
    
    // Step 5: Perform the network request to create the activity on the backend, passing tempId
    activityManager.createActivity(
        duration: duration,
        notes: activityNotes.isEmpty ? nil : activityNotes,
        items: itemsData,
        tempId: tempId
    ) { result in
        DispatchQueue.main.async {
            switch result {
            case .success(let actualActivity):
                // ActivityManager will replace the temporary activity with the actual one.
                activityState.finishActivity()
                print("Activity creation completed.")
                isCreatingActivity = false
                
            case .failure(let error):
                // On failure, remove the temporary activity.
                activityManager.activities.removeAll { $0.id == tempId }
                print("Failed to create activity on backend, removed temporary activity ID: \(tempId)")
                isCreatingActivity = false
                // Optionally, you can show an error alert here.
            }
        }
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
        var itemColumnValues = item.columnValues ?? [:]
        var rowCounts: [String: Int] = [:]
        
        // For each grouped column
        for column in podColumns where column.groupingType == "grouped" {
            let key = String(column.id)
            
            if let existingVal = itemColumnValues[key] {
                // If we do have some data for this column:
                if case .array(let arr) = existingVal {
                    
                    if arr.isEmpty {
                        // Force at least 1 row
                        if column.name == "Set" {
                            itemColumnValues[key] = .array([.number(1.0)])
                        } else {
                            itemColumnValues[key] = .array([.null])
                        }
                        rowCounts[column.groupingType ?? ""] = 1
                    } else {
                        // The array is non-empty; use its count
                        rowCounts[column.groupingType ?? ""] = arr.count
                    }
                } else {
                    // The stored value is not an array—wrap it in an array
                    itemColumnValues[key] = .array([existingVal])
                    rowCounts[column.groupingType ?? ""] = 1
                }
                
            } else {
                // This item has no stored value for this column—init with 1 row
                if column.name == "Set" {
                    itemColumnValues[key] = .array([.number(1.0)])
                } else {
                    itemColumnValues[key] = .array([.null])
                }
                rowCounts[column.groupingType ?? ""] = 1
            }
        }
        
        // Save updated values
        columnValues[item.id] = itemColumnValues
        groupedRowsCounts[item.id] = rowCounts
    }
    
    print("Initialized column values:", columnValues)
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
     
        if column.name == "Set" {
            if values.isEmpty {
                values = [.number(1.0)]  // Initialize with 1 if empty
            }
            values.append(.number(Double(values.count + 1)))
        } else if column.type == "number" {
            if values.isEmpty {
                values = [.number(0)]  // Initialize with 0 if empty
            }
            values.append(values.last ?? .number(0))
        } else {
            if values.isEmpty {
                values = [.null]  // Initialize with null if empty
            }
            values.append(values.last ?? .null)
        }
 
        columnValues[itemId]?[String(column.id)] = .array(values)
    }
    
    groupedRowsCounts[itemId]?[groupType] = currentRowIndex + 1
    print("After updating row count, groupedRowsCounts[\(itemId)][\(groupType)] = \(groupedRowsCounts[itemId]?[groupType] ?? 0)")
}
    
   
private func deleteRow(at index: Int, in columnGroup: [PodColumn], itemId: Int) {
    for column in columnGroup {
        let colKey = String(column.id)
        guard var colValue = columnValues[itemId]?[colKey],
              case .array(var arr) = colValue,
              index < arr.count
        else {
            print("No array value found for item \(itemId), column \(colKey) to delete from")
            continue
        }
        
        print("Deleting row \(index) for item \(itemId), column \(colKey) – original array: \(arr)")
        arr.remove(at: index)
        
        // If we remove the last row, let the array become empty (so the global model sees “no value”).
        // That way, summary sees it as not logged.
        if arr.isEmpty {
            print("Array is empty after deletion => storing empty array in global model.")
        } else if column.name == "Set" {
            // If it’s a Set column, renumber any remaining rows from 1..
            for i in 0..<arr.count {
                arr[i] = .number(Double(i + 1))
            }
        }
        
        columnValues[itemId]?[colKey] = .array(arr)
        print("After deletion, new array for item \(itemId), column \(colKey): \(arr)")
    }
    
    // For the UI: if the array becomes empty, we still want to *display* 1 row.
    let groupType = columnGroup.first?.groupingType ?? ""
    if let firstColumn = columnGroup.first {
        let firstKey = String(firstColumn.id)
        if let val = columnValues[itemId]?[firstKey],
           case .array(let arr) = val {
            // If the array is empty, we set row count = 0, and the UI code will treat 0 as “display 1 row.”
            groupedRowsCounts[itemId]?[groupType] = arr.count
            print("Updated row count for item \(itemId) in group \(groupType) to: \(arr.count)")
        }
    } else {
        groupedRowsCounts[itemId]?[groupType] = 0
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
