//
//  FullActivityLogView.swift
//  Podstack
//
//  Created by Dimi Nunez on 8/28/24.
//

import SwiftUI

struct FullActivityLogView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    let log: PodItemActivityLog
    let onDelete: () -> Void
    @State private var showDeleteAlert = false
    @State private var isDeleting = false
    
    
    var body: some View {
        ZStack {
            (colorScheme == .dark ? Color(rgb: 44,44,44) : .white)
                .edgesIgnoringSafeArea(.all)
            
            ScrollView {
                VStack(spacing: 0) {
                    Capsule()
                        .fill(Color.secondary.opacity(0.6))
                        .frame(width: 35, height: 4)
                        .padding(.top, 10)
                    
                    HStack {
                        Spacer()
                        Button(action: { dismiss() }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 18))
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .foregroundColor(.primary)
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 10) {
                        Text(log.itemLabel)
                            .font(.system(size: 24))
                            .fontWeight(.regular)
                            .padding(.horizontal)
                        
                        Text(log.userName)
                            .font(.system(size: 16))
                            .fontWeight(.semibold)
                            .padding(.horizontal)
                        
                        Text(formattedDate(log.loggedAt))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                        
                        columnValuesGrid
                        
                        if !log.notes.isEmpty {
                            
                            Text("Notes")
                                .font(.headline)
                                .padding(.top)
                                .padding(.horizontal)
                             
                            
                            Text(log.notes)
                                .font(.body)
                                .padding(.horizontal)
                        }
                        Spacer(minLength: 10) // Add space before the delete button
                                                
                                                deleteLogButton
                            
                            
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 20)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(colorScheme == .dark ? Color(rgb: 44,44,44) : .white)
            .cornerRadius(20)
        }
        .alert("Delete Log", isPresented: $showDeleteAlert) {
                  Button("Cancel", role: .cancel) { }
                  Button("Delete", role: .destructive) {
                      deleteLog()
                  }
              } message: {
                  Text("Are you sure you want to delete this log?")
              }
    }
    
    private var deleteLogButton: some View {
        Button(action: {
            showDeleteAlert = true
        }) {
            Text("Delete log")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.red)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
        }
        .padding(.horizontal)
        .padding(.top, 20)
        .disabled(isDeleting)
    }
    
    private func deleteLog() {
           isDeleting = true
           NetworkManager().deleteActivityLog(logId: log.id) { result in
               DispatchQueue.main.async {
                   isDeleting = false
                   switch result {
                   case .success:
                       onDelete()
                       dismiss()
                   case .failure(let error):
                       print("Failed to delete log: \(error.localizedDescription)")
                       // You might want to show an error alert here
                   }
               }
           }
       }
    
    private var columnValuesGrid: some View {
        let columns = Array(log.columnValues).filter { _, value in
            if case .null = value {
                return false
            }
            return true
        }
        return VStack(spacing: 15) {
            ForEach(0..<(columns.count + 1) / 2, id: \.self) { rowIndex in
                HStack(spacing: 20) {
                    ForEach(0..<2) { columnIndex in
                        let index = rowIndex * 2 + columnIndex
                        if index < columns.count {
                            let (key, value) = columns[index]
                            columnView(key: key, value: value)
                        } else {
                            Spacer()
                        }
                    }
                }
            }
        }
        .padding()
        .padding(.top, 20)
    }

    private func columnView(key: String, value: ColumnValue) -> some View {
        VStack(alignment: .leading) {
            Text(key)
                .font(.system(size: 14))
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
            
            Text(valueString(for: value))
                .font(.system(size: 16))
                .fontWeight(.semibold)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func valueString(for value: ColumnValue) -> String {
        switch value {
        case .string(let str):
            return str
        case .number(let num):
            return "\(num)"
        case .null:
            return "" // This case should never be reached due to the filter
        }
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
