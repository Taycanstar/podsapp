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
    
    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 5) {
                Text(log.userEmail)
                    .font(.system(size: 16))
                    .fontWeight(.semibold)
//                    .font(.headline)
                
                Text(columnValuesString(log.columnValues))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            HStack(spacing: 5) {
                Text(formattedDate(log.loggedAt))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Image(systemName: "info.circle")
                    .foregroundColor(.accentColor)
            }
        }
        .padding()
        .background(Color("ltBg"))
        .cornerRadius(10)
        .onAppear {
                   print("Log ID: \(log.id)")
                   print("Raw loggedAt: \(log.loggedAt)")
                   print("Formatted loggedAt: \(formattedDate(log.loggedAt))")
               }
    }
    
    private func columnValuesString(_ values: [String: ColumnValue]) -> String {
        values.map { key, value in
            switch value {
            case .string(let str):
                return "\(key): \(str)"
            case .number(let num):
                return "\(key): \(num)"
            case .null:
                return "\(key): N/A"
            }
        }.joined(separator: ", ")
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
