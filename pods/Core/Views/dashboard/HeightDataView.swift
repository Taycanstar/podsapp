//
//  HeightDataView.swift
//  Pods
//
//  Created by Dimi Nunez on 5/17/25.
//

import SwiftUI
import Charts

struct HeightDataView: View {
    enum Timeframe: String, CaseIterable {
        case week = "W"
        case month = "M"
        case sixMonths = "6M"
        case year = "Y"
        
        var days: Int {
            switch self {
            case .week: return 7
            case .month: return 30
            case .sixMonths: return 182
            case .year: return 365
            }
        }
    }
    
    @State private var logs: [HeightLogResponse] = []
    @State private var timeframe: Timeframe = .week
    @State private var isLoading = false
    
    private let dateFormatter = ISO8601DateFormatter()
    
    var body: some View {
        VStack {
            Picker("Timeframe", selection: $timeframe) {
                ForEach(Timeframe.allCases, id: \.self) { timeframe in
                    Text(timeframe.rawValue)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding()
            
            if isLoading {
                ProgressView()
                    .padding()
            } else if logs.isEmpty {
                Text("No data")
                    .foregroundColor(.gray)
                    .padding()
            } else {
                Chart(logs, id: \.id) { log in
                    if let date = dateFormatter.date(from: log.dateLogged) {
                        LineMark(
                            x: .value("Date", date),
                            y: .value("Height", log.heightCm)
                        )
                        PointMark(
                            x: .value("Date", date),
                            y: .value("Height", log.heightCm)
                        )
                    }
                }
                .chartXScale(domain: xDomain())
                .padding()
            }
        }
        .navigationTitle("Height History")
        .onAppear {
            loadLogs()
        }
        .onChange(of: timeframe) { _ in
            loadLogs()
        }
    }
    
    private func loadLogs() {
        isLoading = true
        guard let email = UserDefaults.standard.string(forKey: "userEmail") else {
            isLoading = false
            return
        }
        
        NetworkManagerTwo.shared.fetchHeightLogs(userEmail: email, limit: 1000, offset: 0) { result in
            isLoading = false
            
            switch result {
            case .success(let response):
                let cutoff = Calendar.current.date(byAdding: .day, value: -timeframe.days, to: Date()) ?? Date()
                
                logs = response.logs.filter { log in
                    if let date = dateFormatter.date(from: log.dateLogged) {
                        return date >= cutoff
                    }
                    return false
                }.sorted {
                    guard let d1 = dateFormatter.date(from: $0.dateLogged),
                          let d2 = dateFormatter.date(from: $1.dateLogged) else { return false }
                    return d1 < d2
                }
                
            case .failure(let error):
                print("Error fetching height logs: \(error)")
            }
        }
    }
    
    private func xDomain() -> ClosedRange<Date> {
        let end = Date()
        let start = Calendar.current.date(byAdding: .day, value: -timeframe.days, to: end) ?? end
        return start...end
    }
}

#Preview {
    HeightDataView()
}
