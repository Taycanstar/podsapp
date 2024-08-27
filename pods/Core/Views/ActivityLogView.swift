//
//  ActivityLogView.swift
//  Podstack
//
//  Created by Dimi Nunez on 8/27/24.
//

import SwiftUI

struct ActivityLogView: View {
    let podId: Int
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color("mxdBg").edgesIgnoringSafeArea(.all)
            
            VStack(alignment: .leading) {
                Text("Hello world")
            }
        }
        .navigationBarBackButtonHidden(true)
        .navigationTitle("Activity Log")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    dismiss()
                }) {
                    Image(systemName: "chevron.left")
                        .foregroundColor(.primary)
                }
            }
        }
    }
}
