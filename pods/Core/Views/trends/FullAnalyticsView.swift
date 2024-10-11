//
//  FullAnalyticsView.swift
//  Podstack
//
//  Created by Dimi Nunez on 10/11/24.
//

import SwiftUI

struct FullAnalyticsView: View {
    let column: PodColumn
    let activityLogs: [PodItemActivityLog]
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                ColumnTrendView(column: column, activityLogs: activityLogs)
                BoundsView(column: column, activityLogs: activityLogs)
                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .padding()
        }
        .navigationBarTitle(column.name, displayMode: .inline)
    }
}


