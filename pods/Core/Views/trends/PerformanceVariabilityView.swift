//
//  PerformanceVariabilityView.swift
//  Podstack
//
//  Created by Dimi Nunez on 10/11/24.
//

import SwiftUI

struct PerformanceVariabilityView: View {
    let column: PodColumn
    let processedData: [ProcessedDataPoint]
    let selectedTimeRange: TimeRange
    
    var body: some View {
        MetricCard(
            title: "Performance variability",
            value: standardDeviation,
            unit: column.name,
            valueFontSize: 22,
            unitFontSize: 16,
            action: { navigateAction()}
            
            
        )
    }
    
    private func navigateAction() {
        print("tapped on performance variability")
    }
    
    private var standardDeviation: Double {
        let values = processedData.map { $0.value }
        guard !values.isEmpty else { return 0 }
        
        let mean = values.reduce(0, +) / Double(values.count)
        let sumOfSquaredAvgDiff = values.map { pow($0 - mean, 2) }.reduce(0, +)
        return sqrt(sumOfSquaredAvgDiff / Double(values.count))
    }

}
