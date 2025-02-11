// GroupedColumnActivityView.swift

import SwiftUI

struct GroupedColumnActivityView: View {
    let itemId: Int
    let columnGroup: [PodColumn]
    let groupedRowsCount: Int
    let onAddRow: () -> Void
    let onDeleteRow: (Int) -> Void
    
    @Binding var columnValues: [String: ColumnValue]
    var focusedField: FocusState<String?>.Binding
    @Binding var expandedColumn: String?
    
    let onValueChanged: () -> Void
    @State private var rows: [Int] = []
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // The header row (column names)
            GroupedColumnHeaderView(columnGroup: columnGroup)
            List {
                ForEach(0..<groupedRowsCount, id: \.self) { rowIdx in
                    GroupedColumnRowActivityView(
                        itemId: itemId,
                        columnGroup: columnGroup,
                        rowIndex: rowIdx,
                        columnValues: $columnValues,
                        focusedField: focusedField,
                        expandedColumn: $expandedColumn,
//                        onDelete: { onDeleteRow(rowIdx) },
                        onDelete: {
                                                   withAnimation {
                                                       rows.removeAll(where: { $0 == rowIdx })
                                                       onDeleteRow(rowIdx)
                                                   }
                                               },
                        onValueChanged: onValueChanged
                    )
                    .listRowInsets(EdgeInsets())
                                        .listRowBackground(Color.clear)
                                        .listRowSeparator(.hidden)
                }
            }
                        .listStyle(PlainListStyle())
                        .frame(minHeight: CGFloat(rows.count * 50)) 
                   
          
            
//            // "Add Row" button at bottom
//            Button(action: onAddRow) {
//                Text("Add Row")
//                    .foregroundColor(.accentColor)
//            }
            Button(action: {
                          withAnimation {
                              rows.append(groupedRowsCount)
                              onAddRow()
                          }
                      }) {
                          Text("Add Row")
                              .foregroundColor(.accentColor)
                      }
            .frame(maxWidth: .infinity)
            .padding(.top, 8)
        }
        .padding(.top, 5)
        .onAppear {
            // If no rows exist, we can auto-add one if desired
            rows = Array(0..<groupedRowsCount)
            
            if groupedRowsCount == 0 {
                onAddRow()
            }
        }
    }
}


struct GroupedColumnRowActivityView: View {
    let itemId: Int
    let columnGroup: [PodColumn]
    let rowIndex: Int
    
    @Binding var columnValues: [String: ColumnValue]
    var focusedField: FocusState<String?>.Binding
    @Binding var expandedColumn: String?
    
    let onDelete: () -> Void
    let onValueChanged: () -> Void
    
    var body: some View {
        HStack(spacing: 15) {
            ForEach(columnGroup, id: \.id) { col in
                GroupedColumnInputActivityView(
                    itemId: itemId,
                    column: col,
                    rowIndex: rowIndex,
                    columnValues: $columnValues,
                    focusedField: focusedField,
                    expandedColumn: $expandedColumn,
                    onValueChanged: onValueChanged
                )
                .frame(maxWidth: .infinity)
            }
        }
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets())
        .listRowSeparator(.hidden)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}



struct GroupedColumnInputActivityView: View {
    let itemId: Int
    let column: PodColumn
    let rowIndex: Int
    
    @Binding var columnValues: [String: ColumnValue]
    var focusedField: FocusState<String?>.Binding
    @Binding var expandedColumn: String?
    
    let onValueChanged: () -> Void
    
    var body: some View {
        let colID = String(column.id)
        let fieldKey =  "\(itemId)_\(column.id)_\(rowIndex)"
        
        let currentVal = columnValues[colID] ?? .null
        let arrayVals: [ColumnValue] = {
            if case .array(let arr) = currentVal { return arr }
            return [currentVal]
        }()
        
        let value = (rowIndex < arrayVals.count) ? arrayVals[rowIndex] : .null
        
        switch column.type {
        
        case "text":
            let txtBinding = Binding<String>(
                get: { value.description },
                set: { newVal in
                    var mutable = arrayVals
                    while mutable.count <= rowIndex {
                        mutable.append(.null)
                    }
                    mutable[rowIndex] = .string(newVal)
                    columnValues[colID] = .array(mutable)
                    onValueChanged()
                }
            )
            
            TextField("", text: txtBinding)
                .focused(focusedField, equals: fieldKey)
                .multilineTextAlignment(.center)
                .textFieldStyle(PlainTextFieldStyle())
                .padding(.vertical, 8)
                .padding(.horizontal)
                .background(Color("iosnp"))
                .cornerRadius(12)
            
        case "number":
            let numBinding = Binding<String>(
                get: { value.description },
                set: { newVal in
                    var mutable = arrayVals
                    while mutable.count <= rowIndex {
                        mutable.append(.null)
                    }
                    if let dbl = Double(newVal) {
                        mutable[rowIndex] = .number(dbl)
                    } else {
                        mutable[rowIndex] = .null
                    }
                    columnValues[colID] = .array(mutable)
                    onValueChanged()
                }
            )
            
            TextField("", text: numBinding)
                .focused(focusedField, equals: fieldKey)
                .multilineTextAlignment(.center)
                .keyboardType(.decimalPad)
                .textFieldStyle(PlainTextFieldStyle())
                .padding(.vertical, 8)
                .padding(.horizontal)
                .background(Color("iosnp"))
                .cornerRadius(12)
            
        case "time":
            Button(action: {
                withAnimation {
                    expandedColumn = (expandedColumn == fieldKey) ? nil : fieldKey
                }
            }) {
                Text(value.description.isEmpty ? "Select Time" : value.description)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
                    .padding(.horizontal)
                    .background(Color("iosnp"))
                    .cornerRadius(12)
            }
            
            if expandedColumn == fieldKey {
                InlineTimePicker(timeValue: Binding(
                    get: {
                        if case .time(let tVal) = value {
                            return tVal
                        }
                        return TimeValue(hours: 0, minutes: 0, seconds: 0)
                    },
                    set: { newVal in
                        var mutable = arrayVals
                        while mutable.count <= rowIndex {
                            mutable.append(.null)
                        }
                        mutable[rowIndex] = .time(newVal)
                        columnValues[colID] = .array(mutable)
                        onValueChanged()
                    }
                ))
                .frame(height: 150)
                .transition(.opacity)
            }
            
        default:
            EmptyView()
        }
    }
}
