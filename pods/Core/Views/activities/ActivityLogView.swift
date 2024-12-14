import SwiftUI


struct ActivityLogView: View {
    @State private var activityLogs: [PodItemActivityLog]
    @State private var searchText: String = ""
    @Environment(\.dismiss) private var dismiss
    let podId: Int
    let columns: [PodColumn]
    @State private var isLoading = false
    @State private var errorMessage: String?
    @EnvironmentObject var viewModel: OnboardingViewModel
    let onDelete: (PodItemActivityLog) -> Void
//    let onLogUpdated: ((PodItemActivityLog) -> Void)?
    
//
//    init(podId: Int, columns: [PodColumn],
//         initialLogs: [PodItemActivityLog] = [],
//         onDelete: @escaping (PodItemActivityLog) -> Void = { _ in },
//         onLogUpdated: ((PodItemActivityLog) -> Void)? = nil) {
//        self.podId = podId
//        self.columns = columns
//        self.onDelete = onDelete
////        self.onLogUpdated = onLogUpdated
//        let onLogUpdated: ((PodItemActivityLog) -> Void)? = { updatedLog in
//            if let index = activityLogs.firstIndex(where: { $0.id == updatedLog.id }) {
//                activityLogs[index] = updatedLog
//            }
//        }
//        _activityLogs = State(initialValue: initialLogs)
//    }

    init(podId: Int, columns: [PodColumn],
             initialLogs: [PodItemActivityLog] = [],
             onDelete: @escaping (PodItemActivityLog) -> Void = { _ in }) {
            self.podId = podId
            self.columns = columns
            self.onDelete = onDelete
            _activityLogs = State(initialValue: initialLogs)
        }

        private func updateLog(_ updatedLog: PodItemActivityLog) {
            if let index = activityLogs.firstIndex(where: { $0.id == updatedLog.id }) {
                activityLogs[index] = updatedLog
            }
        }



    var body: some View {
        ZStack {
        
            if isLoading {
                ProgressView()
            } else if let error = errorMessage {
                Text(error)
                    .foregroundColor(.red)
            } else {
                List {
                    Section {
                       
                            ForEach(filteredLogs) { log in
                                ActivityLogItemView(log: log,  columns: columns, onDelete: { deletedLog in
                                    removeLog(deletedLog)
                                },onLogUpdated: updateLog )
                            }
                            .onDelete { indexSet in
                                  // Get the logs to delete from the filtered logs
                                  let logsToDelete = indexSet.map { filteredLogs[$0] }
                                  
                                  // Delete each log
                                  for log in logsToDelete {
                                      // Call the network delete first
                                      NetworkManager().deleteActivityLog(logId: log.id) { result in
                                          DispatchQueue.main.async {
                                              switch result {
                                              case .success:
                                                  // Remove from the local array after successful network deletion
                                                  removeLog(log)
                                              case .failure(let error):
                                                  print("Failed to delete log: \(error.localizedDescription)")
                                                  // You might want to show an error message to the user here
                                              }
                                          }
                                      }
                                  }
                              }
   


                        
                    }
                    .listRowBackground(Color("bg"))
                }
                .listStyle(GroupedListStyle())
        
              

            .onAppear {
                if activityLogs.isEmpty {
                    loadLogs()
                }
            }
            }
        }
        .navigationTitle("Activities")
        .navigationBarTitleDisplayMode(.large)
        .toolbarBackground(.visible, for: .navigationBar)
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search")
    
    }
    
    // Add this computed property
    private var filteredLogs: [PodItemActivityLog] {
        if searchText.isEmpty {
            return activityLogs
        }
        
        return activityLogs.filter { log in
            // Customize the search criteria here
            log.itemLabel.localizedCaseInsensitiveContains(searchText) ||
            log.userName.localizedCaseInsensitiveContains(searchText) ||
            (log.notes.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }
    private func loadLogs() {
        isLoading = true
        errorMessage = nil
        NetworkManager().fetchUserActivityLogs(podId: podId, userEmail: viewModel.email) { result in
            DispatchQueue.main.async {
                isLoading = false
                switch result {
                case .success(let logs):
                    self.activityLogs = logs
                    
                case .failure(let error):
                    print("Failed to fetch activity logs: \(error)")
                }
            }
        }
    }
    
    private func removeLog(_ log: PodItemActivityLog) {
        activityLogs.removeAll { $0.id == log.id }
    }
}

struct ActivityLogItemView: View {
    let log: PodItemActivityLog
    let columns: [PodColumn]
    let onDelete: (PodItemActivityLog) -> Void
    let onLogUpdated: (PodItemActivityLog) -> Void


    
    var body: some View {
//        NavigationLink(value: NavigationDestination.fullActivityLog(log: log , columns: columns, onUpdate: onLogUpdated)) {
        NavigationLink(value: NavigationDestination.fullActivityLog(
            log: log,
            columns: columns,
            onLogUpdated: onLogUpdated)){
                
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(log.itemLabel)
                        .font(.system(size: 15))
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                HStack(spacing: 5) {
                    Text(formattedDate(log.loggedAt))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            .background(Color("bg"))
        }
    }
    
    

    private func columnValuesString(_ values: [String: ColumnValue]) -> String {
        let result = values.compactMap { key, value -> String? in
            switch value {
            case .string(let str):
                return str.isEmpty ? nil : "\(str) (\(key))"
            case .number(let num):
                return "\(num) (\(key))"
            case .time(let timeValue):
                return "\(timeValue.toString) (\(key))"
            case .array(let array):
                let arrayString = array.map { $0.description }.joined(separator: ", ")
                return arrayString.isEmpty ? nil : "\(arrayString) (\(key))"
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
