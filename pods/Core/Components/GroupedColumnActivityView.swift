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
            GroupedColumnHeaderView(columnGroup: columnGroup)

            List {
                // If groupedRowsCount == 0, we display 1 row *visually*, but do *not* call onAddRow in the model.
                // ForEach(0 ..< max(1, groupedRowsCount), id: \.self) { rowIdx in
                ForEach(0 ..< groupedRowsCount, id: \.self) { rowIdx in
                    GroupedColumnRowActivityView(
                        itemId: itemId,
                        columnGroup: columnGroup,
                        rowIndex: rowIdx,
                        columnValues: $columnValues,
                        focusedField: focusedField,
                        expandedColumn: $expandedColumn,
                        onDelete: {
                            withAnimation {
                                rows.removeAll { $0 == rowIdx }
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
        .onAppear {
            // Don’t store a default row in the model if it's empty!
            // Just show 1 placeholder visually in the UI.
            rows = Array(0 ..< max(1, groupedRowsCount))
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
                    print("Updated column \(colID) for item \(itemId) at row \(rowIndex) to: \(mutable)")
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
