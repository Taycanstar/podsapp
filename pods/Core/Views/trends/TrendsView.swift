//
//  TrendsView.swift
//  Podstack
//
//  Created by Dimi Nunez on 9/19/24.
//

import SwiftUI
import Mixpanel

//struct TrendsView: View {
//    let activityLogs: [PodItemActivityLog]
//    let podColumns: [PodColumn]
//    @Environment(\.colorScheme) var colorScheme
//
//    var body: some View {
//        List {
//            ForEach(podColumns.filter { $0.type == "number" || $0.type == "time" }, id: \.name) { column in
//                VStack(spacing: 0) {
//                    HStack {
//                        NavigationLink(destination: ColumnDetailView(column: column, activityLogs: activityLogs)
//                            .onAppear{
//                                Mixpanel.mainInstance().track(event: "Tapped Column Trends", properties: ["column_name": column.name])
//                            })
//                          
//                        {
//                            Text(column.name)
//                                .font(.system(size: 16))
//                                .frame(maxWidth: .infinity, alignment: .leading)
//                                .padding(.vertical, 16)
//                        }
//                      
//                    }
//                    .padding(.horizontal, 17)
//                    .buttonStyle(PlainButtonStyle())
//                    
//                    Divider()
//                        .background(colorScheme == .dark ? Color(rgb: 71, 71, 71) : Color(rgb: 219, 223, 236))
//                }
//              
//            }
//            .listRowInsets(EdgeInsets())
//            .listRowSeparator(.hidden)
//            .listRowBackground(Color("dkBg"))
//        }
//        .listStyle(PlainListStyle())
//        .navigationTitle("Trends")
//        .navigationBarTitleDisplayMode(.inline)
//        .background(Color("dkBg"))
//        .scrollContentBackground(.hidden)
//    }
//}
//
//struct ColumnDetailView: View {
//    let column: PodColumn
//    let activityLogs: [PodItemActivityLog]
//
//    var body: some View {
////        ColumnTrendView(column: column, activityLogs: activityLogs)
//        FullAnalyticsView(column: column, activityLogs: activityLogs)
//
//    }
//}

struct TrendsView: View {
    let itemId: Int
    let activities: [Activity]
    let podColumns: [PodColumn]
    @Environment(\.colorScheme) var colorScheme

    // Get the highest value for each activity's column
    func getHighestValue(for column: PodColumn, in activity: Activity) -> Double? {
        let relevantItem = activity.items.first { $0.itemId == itemId }
        guard let columnValue = relevantItem?.columnValues[String(column.id)] else { return nil }
        
        switch columnValue {
        case .number(let value):
            return value
        case .time(let timeValue):
            return Double(timeValue.totalSeconds)
        case .array(let values):
            // For array values, find the highest numeric value
            let numericValues = values.compactMap { value -> Double? in
                switch value {
                case .number(let num): return num
                case .time(let time): return Double(time.totalSeconds)
                default: return nil
                }
            }
            return numericValues.max()
        default:
            return nil
        }
    }

    var body: some View {
        List {
            ForEach(podColumns.filter { $0.type == "number" || $0.type == "time" }, id: \.name) { column in
                VStack(spacing: 0) {
                    HStack {
                        NavigationLink(
                            destination: FullAnalyticsView(
                                column: column,
                                activities: activities,
                                itemId: itemId,
                                getHighestValue: { activity in
                                    getHighestValue(for: column, in: activity)
                                }
                            )
                            .onAppear {
                                Mixpanel.mainInstance().track(event: "Tapped Column Trends", properties: ["column_name": column.name])
                            }
                        ) {
                            Text(column.name)
                                .font(.system(size: 16))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 16)
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
        .navigationTitle("Trends")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color("dkBg"))
        .scrollContentBackground(.hidden)
    }
}
