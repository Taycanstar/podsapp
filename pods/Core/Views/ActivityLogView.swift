import SwiftUI

struct ActivityLogView: View {
    let activityLogs: [PodItemActivityLog]
    @Environment(\.dismiss) private var dismiss

    
    var body: some View {
        ZStack {
            Color("mxdBg").edgesIgnoringSafeArea(.all)
            
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    ForEach(activityLogs) { log in
                        ActivityLogItemView(log: log)
                    }
                }
                .padding()
            }
        }
//        .navigationBarBackButtonHidden(true)
        .navigationTitle("Activity Log")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct ActivityLogItemView: View {
    let log: PodItemActivityLog
    @State private var showFullLog = false
    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 5) {
                Text(log.userName)
                    .font(.system(size: 15))
                    .fontWeight(.medium)
//                    .font(.headline)
                
                Text(log.itemLabel)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            HStack(spacing: 5) {
                Text(formattedDate(log.loggedAt))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Image(systemName: "info.circle")
                    .font(.system(size: 20))
                    .foregroundColor(.accentColor)
                    .onTapGesture {
                                          showFullLog = true
                                      }
            }
        }
        .padding()
        .background(Color("mdBg"))
        .cornerRadius(10)
        .onAppear {
                   print("Log ID: \(log.id)")
                   print("Raw loggedAt: \(log.loggedAt)")
                   print("Formatted loggedAt: \(formattedDate(log.loggedAt))")
               }
        .sheet(isPresented: $showFullLog) {
                  FullActivityLogView(log: log)
              }
    }
    
    private func columnValuesString(_ values: [String: ColumnValue]) -> String {
        let result = values.compactMap { key, value in
            switch value {
            case .string(let str):
                return str.isEmpty ? nil : "\(str) \(key)"
            case .number(let num):
                return "\(num) \(key)"
            case .null:
                return nil
            }
        }.joined(separator: ", ")
        
        return result.isEmpty ? "No data" : result
    }
    
    private func formattedDate(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            let formatter = DateFormatter()
            formatter.dateFormat = "h:mm a"
            return formatter.string(from: date)
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else if calendar.isDate(date, equalTo: Date(), toGranularity: .weekOfYear) {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE"
            return formatter.string(from: date)
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MM/dd/yy"
            return formatter.string(from: date)
        }
    }
}