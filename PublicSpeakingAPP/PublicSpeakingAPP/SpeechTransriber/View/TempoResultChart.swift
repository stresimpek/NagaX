//
//  TempoResultChart.swift
//  PublicSpeakingAPP
//
//  Created by Feby Agatha Christie Kurniawan on 10/11/25.
//

import SwiftUI
import Charts

struct TempoResultChart: View {
    let tempoSeries: [TempoPoint]
    
    private let idealMin: Double = 110.0
    private let idealMax: Double = 140.0
    private let cukupMin: Double = 90.0
    private let cukupMax: Double = 160.0
    private let maxY: Double = 200.0

    private var normalized: [TempoPoint] {
        guard let t0 = tempoSeries.first?.time else { return tempoSeries }
        return tempoSeries.map { .init(time: $0.time - t0, wpm: $0.wpm) }
    }
    
    private var chartData: [TempoPoint] {
        normalized.map { .init(time: $0.time, wpm: min($0.wpm, maxY)) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Words Per Minute (WPM) over time")
                .font(.headline)
                .padding(.leading, 8)

            Chart {
                let lastT = normalized.last?.time ?? 1.0

                // Band "Ideal" (A) -> Natural & Clear
                RectangleMark(xStart: .value("s0", 0), xEnd: .value("s1", lastT),
                              yStart: .value("y0", idealMin), yEnd: .value("y1", idealMax))
                    .foregroundStyle(.green.opacity(0.15))

                // Band "Cukup Lambat" (B) -> Slow For Emphasis
                RectangleMark(xStart: .value("s0", 0), xEnd: .value("s1", lastT),
                              yStart: .value("y0", cukupMin), yEnd: .value("y1", idealMin))
                    .foregroundStyle(.yellow.opacity(0.15))

                // Band "Cukup Cepat" (B) -> Energetic
                RectangleMark(xStart: .value("s0", 0), xEnd: .value("s1", lastT),
                              yStart: .value("y0", idealMax), yEnd: .value("y1", cukupMax))
                    .foregroundStyle(.yellow.opacity(0.15))
                
                // Band "Terlalu Lambat" (C) -> To Slow
                RectangleMark(xStart: .value("s0", 0), xEnd: .value("s1", lastT),
                              yStart: .value("y0", 0), yEnd: .value("y1", cukupMin))
                    .foregroundStyle(.orange.opacity(0.15))
                
                // Band "Terlalu Cepat" (C) -> To Fast
                RectangleMark(xStart: .value("s0", 0), xEnd: .value("s1", lastT),
                              yStart: .value("y0", cukupMax), yEnd: .value("y1", maxY))
                    .foregroundStyle(.orange.opacity(0.15))

                ForEach(chartData) { p in
                    LineMark(
                        x: .value("Time (s)", p.time),
                        y: .value("WPM", p.wpm)
                    )
                    .interpolationMethod(.monotone)
                    .foregroundStyle(.blue)
                }
            }
            .chartXScale(domain: 0...(max(normalized.last?.time ?? 0, 1)))
            .chartYScale(domain: 0...maxY)
            .frame(height: 160)
            .padding(.horizontal, 12)
        }
    }
}
