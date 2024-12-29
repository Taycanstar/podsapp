// SingularColumnActivityView.swift

import SwiftUI

struct SingularColumnActivityView: View {
    let itemId: Int
    let column: PodColumn
    @Binding var columnValues: [String: ColumnValue]
    
    // Focus from the parent ActivityView
    var focusedField: FocusState<String?>.Binding
    
    // Expanded column for time pickers, etc.
    @Binding var expandedColumn: String?
    
    let onValueChanged: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(column.name)
                .font(.system(size: 16))
                .fontWeight(.semibold)
                .fontDesign(.rounded)
                .foregroundColor(.primary)
                .kerning(0.2)
            
            // This input handles text, numbers, or time (depending on column.type)
            SingularColumnInputActivityView(
                itemId: itemId,
                column: column,
                columnValues: $columnValues,
                focusedField: focusedField,
                expandedColumn: $expandedColumn,
                onValueChanged: onValueChanged
            )
//            .padding(.vertical, 8)
            .background(Color("iosnp"))
            .cornerRadius(8)
        }
    }
}

// SingularColumnInputActivityView.swift


struct SingularColumnInputActivityView: View {
    let itemId: Int
    let column: PodColumn
    @Binding var columnValues: [String: ColumnValue]
    var focusedField: FocusState<String?>.Binding
    @Binding var expandedColumn: String?
    
    let onValueChanged: () -> Void
    
    var body: some View {
        let colID = String(column.id)
        switch column.type {
        
        case "text":
            let textBinding = Binding<String>(
                get: { columnValues[colID]?.description ?? "" },
                set: {
                    columnValues[colID] = .string($0)
                    onValueChanged()
                }
            )
            
            TextField("", text: textBinding)
                // Focus ID => itemId + "_" + colID from parent
                .focused(focusedField, equals: focusKey())
                .font(.system(size: 16))
                .foregroundColor(.primary)
                .textFieldStyle(PlainTextFieldStyle())
                .padding(.vertical, 8)
                .padding(.horizontal)
                .background(Color("iosnp"))
                .cornerRadius(8)
            
        case "number":
            let numBinding = Binding<String>(
                get: { columnValues[colID]?.description ?? "" },
                set: { newVal in
                    if let doubleVal = Double(newVal) {
                        columnValues[colID] = .number(doubleVal)
                    } else {
                        columnValues[colID] = .null
                    }
                    onValueChanged()
                }
            )
            
            TextField("", text: numBinding)
                .focused(focusedField, equals: focusKey())
                .font(.system(size: 16))
                .keyboardType(.decimalPad)
                .foregroundColor(.primary)
                .textFieldStyle(PlainTextFieldStyle())
                .padding(.vertical, 8)
                .padding(.horizontal)
                .background(Color("iosnp"))
                .cornerRadius(8)
            
        case "time":
            // If column is "time", we show a button that toggles a time picker
            Button(action: {
                withAnimation {
                    expandedColumn = (expandedColumn == focusKey()) ? nil : focusKey()
                }
            }) {
                Text(columnValues[colID]?.description.isEmpty == false ? columnValues[colID]?.description ?? "Select Time" : "Select Time")
                    .font(.system(size: 16))
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
                    .padding(.horizontal)
                    .background(Color("iosnp"))
                    .cornerRadius(8)
            }
            
            if expandedColumn == focusKey() {
                InlineTimePicker(timeValue: Binding(
                    get: {
                        if case .time(let tVal) = columnValues[colID] {
                            return tVal
                        }
                        return TimeValue(hours: 0, minutes: 0, seconds: 0)
                    },
                    set: {
                        columnValues[colID] = .time($0)
                        onValueChanged()
                    }
                ))
                .frame(height: 150)
                .transition(.opacity)
            }
            
        default:
            // Fallback if needed
            EmptyView()
        }
    }
    
    // Generate a unique identifier matching the parent's "itemId_columnId"
    private func focusKey() -> String {
        // item ID + column ID, e.g. "95_20"
        // So the parent can parse it properly.
  
        return "\(itemId)_\(column.id)"
    }

}

