//
//  ItemTrendsView.swift
//  Podstack
//
//  Created by Dimi Nunez on 9/23/24.
//

import SwiftUI

struct ItemTrendsView: View {
    let podId: Int
    let podItems: [PodItem]
    let podColumns: [PodColumn]
    @StateObject private var viewModel = ItemTrendsViewModel()
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        List {
            ForEach(podItems, id: \.id) { item in
                VStack(spacing: 0) {
                    HStack {
                        NavigationLink(destination: TrendsView(activityLogs: viewModel.activityLogs[item.id] ?? [], podColumns: podColumns)) {
                            Text(item.metadata)
                                .font(.system(size: 16))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 18)
                        }
                    }
                    .padding(.horizontal, 17)
                    .buttonStyle(PlainButtonStyle())
                    
                    Divider()
                        .background(colorScheme == .dark ? Color(rgb: 71, 71, 71) : Color(rgb: 219, 223, 236))
                }
            }
            .listRowInsets(EdgeInsets())
            .listRowSeparator(.hidden)
            .listRowBackground(Color("dkBg"))
        }
        .listStyle(PlainListStyle())
        .navigationTitle("Select Item")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color("dkBg"))
        .scrollContentBackground(.hidden)
        .onAppear {
            viewModel.fetchActivityLogs(for: podId)
        }
    }
}

class ItemTrendsViewModel: ObservableObject {
    @Published var activityLogs: [Int: [PodItemActivityLog]] = [:]
    private let networkManager = NetworkManager()

    func fetchActivityLogs(for podId: Int) {
        networkManager.fetchPodActivityLogs(podId: podId) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let logs):
                    self.activityLogs = Dictionary(grouping: logs, by: { $0.itemId })
                case .failure(let error):
                    print("Failed to fetch activity logs: \(error)")
                }
            }
        }
    }
}

//struct ItemTrendsView: View {
//    let podItems: [PodItem]
//    let activityLogs: [PodItemActivityLog]
//    let podColumns: [PodColumn]
//    @Environment(\.colorScheme) var colorScheme
//
//    var body: some View {
//        List {
//            ForEach(podItems, id: \.id) { item in
//                VStack(spacing: 0) {
//                    HStack {
//                        NavigationLink(destination: TrendsView(activityLogs: activityLogs.filter { $0.itemId == item.id }, podColumns: podColumns)) {
//                            Text(item.metadata)
//                                .font(.system(size: 16))
//                                .frame(maxWidth: .infinity, alignment: .leading)
//                                .padding(.vertical, 18)
//                        }
//                    }
//                    .padding(.horizontal, 17)
//                    .buttonStyle(PlainButtonStyle())
//                    
//                    Divider()
//                        .background(colorScheme == .dark ? Color(rgb: 71, 71, 71) : Color(rgb: 219, 223, 236))
//                }
//            }
//            .listRowInsets(EdgeInsets())
//            .listRowSeparator(.hidden)
//            .listRowBackground(Color("dkBg"))
//        }
//        .listStyle(PlainListStyle())
//        .navigationTitle("Select Item")
//        .navigationBarTitleDisplayMode(.inline)
//        .background(Color("dkBg"))
//        .scrollContentBackground(.hidden)
//    }
//}
