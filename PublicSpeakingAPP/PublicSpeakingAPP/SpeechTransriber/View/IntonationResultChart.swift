//
//  IntonationResultChart.swift
//  PublicSpeakingAPP
//
//  Created by Regina Celine Adiwinata on 02/11/25.
//

import SwiftUI
import Charts

struct PitchPoint: Identifiable, Hashable {
    let id = UUID()
    let time: Double
    let pitch: Double
}

struct IntonationResultChart: View {
    let pitchSeries: [PitchPoint]
    // Same thresholds you use for grading:
    private let bandLow: Double = 18.0
    private let bandHigh: Double = 35.0
    private let maxY: Double = 50.0  // cap for chart

    // Window config
    var windowSeconds: Double = 10.0     // match your analyzer window
    var stepSeconds: Double = 1.0        // compute one point per second

    // Normalize to start at 0s
    private var normalized: [PitchPoint] {
        guard let t0 = pitchSeries.first?.time else { return pitchSeries }
        return pitchSeries.map { .init(time: $0.time - t0, pitch: $0.pitch) }
    }

    // Build rolling std series
    private var rollingStd: [PitchPoint] {
        guard let lastT = normalized.last?.time, lastT > 0 else { return [] }
        var out: [PitchPoint] = []
        var t = 0.0
        while t <= lastT {
            let windowStart = max(0.0, t - windowSeconds)
            let window = normalized.filter { $0.time >= windowStart && $0.time <= t }.map { $0.pitch }
            if window.count >= 2 {
                let mean = window.reduce(0,+) / Double(window.count)
                let varSum = window.reduce(0) { $0 + pow($1 - mean, 2) }
                let std = sqrt(varSum / Double(window.count))
                out.append(.init(time: t, pitch: std))
            }
            t += stepSeconds
        }
        return out
    }

    // Optional: smooth with EMA for extra silky lines
    private var smoothedRollingStd: [PitchPoint] {
        let alpha = 0.3 // 0..1 (higher -> more reactive)
        var ema: Double?
        return rollingStd.map { p in
            let v = (ema == nil) ? p.pitch : (alpha * p.pitch + (1 - alpha) * ema!)
            ema = v
            return .init(time: p.time, pitch: min(v, maxY))
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Pitch Variability (Std Dev over time)")
                .font(.headline)
                .padding(.leading, 8)

            Chart {
                // Bands for A/B/C thresholds
                if let lastT = normalized.last?.time, lastT > 0 {
                    // C (too flat): 0 .. <18
                    RectangleMark(xStart: .value("s0", 0), xEnd: .value("s1", lastT),
                                  yStart: .value("y0", 0), yEnd: .value("y1", bandLow))
                        .foregroundStyle(.orange.opacity(0.10))
                    // B (18..25)
                    RectangleMark(xStart: .value("s0", 0), xEnd: .value("s1", lastT),
                                  yStart: .value("y0", bandLow), yEnd: .value("y1", bandHigh))
                        .foregroundStyle(.green.opacity(0.10))
                    // A (25..35) — your top band; we cap display at maxY
                    RectangleMark(xStart: .value("s0", 0), xEnd: .value("s1", lastT),
                                  yStart: .value("y0", bandHigh), yEnd: .value("y1", maxY))
                        .foregroundStyle(.yellow.opacity(0.10))
                }

                ForEach(smoothedRollingStd) { p in
                    LineMark(
                        x: .value("Time (s)", p.time),
                        y: .value("Std Dev", p.pitch)
                    )
                    .interpolationMethod(.monotone)
                }
            }
            .chartXScale(domain: 0...(max(normalized.last?.time ?? 0, 1)))
            .chartYScale(domain: 0...maxY)
            .frame(height: 160)
            .padding(.horizontal, 12)
        }
    }
}
