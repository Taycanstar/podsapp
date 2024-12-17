//
//  ItemTrendsView.swift
//  Podstack
//
//  Created by Dimi Nunez on 9/23/24.
//

import SwiftUI
import Mixpanel

struct ItemTrendsView: View {
    let podId: Int
    let podItems: [PodItem]
    let podColumns: [PodColumn]
//    @StateObject private var viewModel = ItemTrendsViewModel()
    @State private var activityLogs: [Int: [PodItemActivityLog]] = [:]
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var viewModel: OnboardingViewModel

    var body: some View {
        List {
            ForEach(podItems, id: \.id) { item in
                VStack(spacing: 0) {
                    HStack {
                        NavigationLink(destination: TrendsView(activityLogs: activityLogs[item.id] ?? [], podColumns: podColumns)
                            .onAppear{
                                Mixpanel.mainInstance().track(event: "Tapped Item Trends", properties: ["item_id": item.id])
                            }){
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
            fetchActivityLogs(for: podId)
        }
    }
    
    private func fetchActivityLogs(for podId: Int) {
        let networkManager = NetworkManager()
        networkManager.fetchUserActivityLogs2(podId: podId, userEmail: viewModel.email) { result in
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



