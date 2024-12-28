//
//  ActivityView.swift
//  Pods
//
//  Created by Dimi Nunez on 12/26/24.
//

import SwiftUI

struct ActivityView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    @StateObject private var stopwatch = Stopwatch()
    @Binding var pod: Pod
    @Binding var podColumns: [PodColumn]
    @Binding var items: [PodItem]
    @State private var columnValues: [Int: [String: ColumnValue]] = [:]
    @State private var groupedRowsCounts: [Int: [String: Int]] = [:]
    @State private var expandedColumn: String?
    @FocusState private var focusedField: String?
    
    private func groupColumns(_ columns: [PodColumn]) -> [[PodColumn]] {
        let groupedColumns = columns.filter { $0.groupingType == "grouped" }
        let singularColumns = columns.filter { $0.groupingType == "singular" }
        return [groupedColumns, singularColumns].filter { !$0.isEmpty }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color("iosbg")
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header with timer
                    HStack {
                        Image(systemName: "timer")
                            .font(.system(size: 18))
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Text(stopwatch.formattedTime)
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.primary)
                            .onAppear { stopwatch.start() }
                            .onDisappear { stopwatch.stop() }
                        
                        Spacer()
                        
                        Button(action: { dismiss() }) {
                            Text("Finish")
                                .font(.system(size: 18))
                                .foregroundColor(Color("iosred"))
                        }
                    }
                    .padding()
                    
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
                                                    Text(column.name)
                                                        .font(.system(size: 16))
                                                        .fontWeight(.semibold)
                                                        .fontDesign(.rounded)
                                                        .foregroundColor(.primary)
                                                        .kerning(0.2)
                                                    
                                                    SingularColumnView(
                                                        column: column,
                                                        columnValues: bindingForItem(item.id),
                                                        focusedField: _focusedField,
                                                        expandedColumn: $expandedColumn,
                                                        onValueChanged: { }
                                                    )
                                                }
                                            }
                                        } else {
                                            GroupedColumnView(
                                                columnGroup: columnGroup,
                                                groupedRowsCount: groupedRowsCounts[item.id]?[columnGroup.first?.groupingType ?? ""] ?? 1,
                                                onAddRow: { addRow(for: columnGroup, itemId: item.id) },
                                                onDeleteRow: { index in
                                                    deleteRow(at: index, in: columnGroup, itemId: item.id)
                                                },
                                                columnValues: bindingForItem(item.id),
                                                focusedField: _focusedField,
                                                expandedColumn: $expandedColumn,
                                                onValueChanged: { }
                                            )

                                        }
                                    }
                                }
                                .padding()
//                                .padding(.horizontal)
                            }
                        }
//                        .padding(.vertical)
                        
                    
                        Button(action: onCancelActivity) {
                            Text("Cancel Activity")
                                .font(.system(size: 16))
                                        .fontWeight(.medium)
                                        .foregroundColor(Color("iosred"))
                                        .frame(maxWidth: .infinity)  // Move frame here
                                        .padding(.vertical, 10)
                                        .background(Color("iosred").opacity(0.1))  // Move background here
                                        .cornerRadius(8)
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 40)
                    
                    }
                    .edgesIgnoringSafeArea(.bottom)
                    
                }
            }
        }
        .navigationBarHidden(true)
   
        .onAppear {
            initializeColumnValues()
        }
    }
    
    private func onCancelActivity() {
        
        print("Cancelling Activity")
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
    private var timer: Timer?
    
    var formattedTime: String {
        let hours = Int(elapsedTime) / 3600
        let minutes = Int(elapsedTime) / 60 % 60
        let seconds = Int(elapsedTime) % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
    
    func start() {
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.elapsedTime += 1
        }
    }
    
    func stop() {
        timer?.invalidate()
        timer = nil
    }
    
    func reset() {
        stop()
        elapsedTime = 0
    }
    
    deinit {
        stop()
    }
}
