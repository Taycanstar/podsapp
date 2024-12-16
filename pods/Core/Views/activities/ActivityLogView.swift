import SwiftUI

struct ActivityLogView: View {
    @State private var activityLogs: [PodItemActivityLog]
    @State private var searchText: String = ""
    @State private var filteredLogs: [PodItemActivityLog] = []
    @Environment(\.dismiss) private var dismiss
    let podId: Int
    let columns: [PodColumn]
    @State private var isLoading = false
    @State private var errorMessage: String?
    @EnvironmentObject var viewModel: OnboardingViewModel
    let onDelete: (PodItemActivityLog) -> Void

    init(podId: Int, columns: [PodColumn],
         initialLogs: [PodItemActivityLog] = [],
         onDelete: @escaping (PodItemActivityLog) -> Void = { _ in }) {
        self.podId = podId
        self.columns = columns
        self.onDelete = onDelete
        _activityLogs = State(initialValue: initialLogs)
        _filteredLogs = State(initialValue: initialLogs)
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
//                        ForEach(Array(filteredLogs.enumerated()), id: \.element.id) { index, _ in
                        ForEach(filteredLogs, id: \.id) { log in
                                                   if let activityIndex = activityLogs.firstIndex(where: { $0.id == log.id }) {
                                                       NavigationLink(value: NavigationDestination.fullActivityLog(
                                                           log: $activityLogs[activityIndex], // ✅ Correct Binding
                                                           columns: columns,
                                                           onLogUpdated: { updatedLog in
                                                               activityLogs[activityIndex] = updatedLog // ✅ Correct Update
                                                               loadLogs()
                                                           }
                                                       )) {
                                                           logRowContent(for: log)
                                                       }
                                                   } else {
                                                       // Optionally handle logs not found in activityLogs
                                                       logRowContent(for: log)
                                                   }
                                               }

    
                        .onDelete { indexSet in
                            let logsToDelete = indexSet.map { filteredLogs[$0] }
                            for log in logsToDelete {
                                NetworkManager().deleteActivityLog(logId: log.id) { result in
                                    DispatchQueue.main.async {
                                        switch result {
                                        case .success:
                                            removeLog(log)
                                        case .failure(let error):
                                            print("Failed to delete log: \(error.localizedDescription)")
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .listRowBackground(Color("bg"))
                }
                .listStyle(GroupedListStyle())
                .refreshable { // ✅ Add pull-to-refresh
                    loadLogs()
                                }
                .onAppear {
                    if activityLogs.isEmpty {
                        loadLogs()
                    } else {
                        updateFilteredLogs() // ✅ Ensure filteredLogs is updated
                    }
                }
                .onChange(of: searchText) { _ in
                    updateFilteredLogs() // ✅ Update filteredLogs when searchText changes
                }

             
            }
        }
        .navigationTitle("Activities")
        .navigationBarTitleDisplayMode(.large)
        .toolbarBackground(.visible, for: .navigationBar)
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search")
    }

    private func logRowContent(for log: PodItemActivityLog) -> some View {
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
    
//    private var filteredLogs: [PodItemActivityLog] {
//        if searchText.isEmpty {
//            return activityLogs
//        }
//        
//        return activityLogs.filter { log in
//            log.itemLabel.localizedCaseInsensitiveContains(searchText) ||
//            log.userName.localizedCaseInsensitiveContains(searchText) ||
//            (log.notes.localizedCaseInsensitiveContains(searchText))
//        }
//    }

//    private func loadLogs() {
//        isLoading = true
//        errorMessage = nil
//        NetworkManager().fetchUserActivityLogs(podId: podId, userEmail: viewModel.email) { result in
//            DispatchQueue.main.async {
//                isLoading = false
//                switch result {
//                case .success(let logs):
//
//                    self.activityLogs = logs
//                    self.filteredLogs = searchText.isEmpty ? logs : logs.filter { log in
//                                       log.itemLabel.localizedCaseInsensitiveContains(searchText) ||
//                                       log.userName.localizedCaseInsensitiveContains(searchText) ||
//                                       (log.notes.localizedCaseInsensitiveContains(searchText) ?? false)
//                                   }
//                case .failure(let error):
//                    print("Failed to fetch activity logs: \(error)")
//                }
//            }
//        }
//    }
    private func loadLogs() {
        isLoading = true
        errorMessage = nil

        // Reset state variables
        activityLogs = []
        filteredLogs = []

        NetworkManager().fetchUserActivityLogs(podId: podId, userEmail: viewModel.email) { result in
            DispatchQueue.main.async {
                isLoading = false
                switch result {
                case .success(let logs):
                    print("Fetched logs: \(logs)")
                    activityLogs = logs // ✅ Replace with new logs
                    updateFilteredLogs() // Sync filteredLogs
                case .failure(let error):
                    print("Failed to fetch activity logs: \(error)")
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    
    private func updateFilteredLogs() {
         if searchText.isEmpty {
             filteredLogs = activityLogs
         } else {
             filteredLogs = activityLogs.filter { log in
                 log.itemLabel.localizedCaseInsensitiveContains(searchText) ||
                 log.userName.localizedCaseInsensitiveContains(searchText) ||
                 (log.notes.localizedCaseInsensitiveContains(searchText) ?? false)
             }
         }
     }
   
    
    private func removeLog(_ log: PodItemActivityLog) {
        activityLogs.removeAll { $0.id == log.id }
        updateFilteredLogs()
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
  
