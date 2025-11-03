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
    let idealRange: ClosedRange<Double> = 120...180

    // Normalize waktu agar mulai dari 0
    private var normalizedSeries: [PitchPoint] {
        guard let firstTime = pitchSeries.first?.time else { return pitchSeries }
        return pitchSeries.map { p in
            PitchPoint(time: p.time - firstTime, pitch: p.pitch)
        }
    }

    private var totalDuration: Double {
        normalizedSeries.last?.time ?? 0
    }

    // Tentukan jarak tick axis X sesuai panjang durasi
    private var tickInterval: Double {
        switch totalDuration {
        case 0..<30: return 5        // tiap 5 detik kalau durasi pendek
        case 30..<90: return 15      // tiap 15 detik untuk durasi sedang
        case 90..<180: return 30     // tiap 30 detik untuk durasi panjang
        default: return 60           // kalau lebih dari 3 menit tiap 1 menit
        }
    }

    // Bikin list tick values
    private var tickValues: [Double] {
        stride(from: 0, through: totalDuration, by: tickInterval).map { $0 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Pitch Intonation (Hz)")
                .font(.headline)
                .padding(.leading, 8)

            Chart {
                // Area ideal range
                if totalDuration > 0 {
                    RectangleMark(
                        xStart: .value("Start", 0),
                        xEnd: .value("End", totalDuration),
                        yStart: .value("Ideal Min", idealRange.lowerBound),
                        yEnd: .value("Ideal Max", idealRange.upperBound)
                    )
                    .foregroundStyle(Color.green.opacity(0.12))
                }

                // Garis pitch
                ForEach(normalizedSeries) { point in
                    LineMark(
                        x: .value("Time (s)", point.time),
                        y: .value("Pitch (Hz)", point.pitch)
                    )
                    .interpolationMethod(.monotone)
                    .foregroundStyle(.blue)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                }

                // Titik dalam ideal range
                ForEach(normalizedSeries) { point in
                    if idealRange.contains(point.pitch) {
                        PointMark(
                            x: .value("Time", point.time),
                            y: .value("Pitch", point.pitch)
                        )
                        .foregroundStyle(.white)
                        .annotation(position: .top) {
                            Text("Just Right")
                                .font(.caption2)
                                .padding(4)
                                .background(.ultraThinMaterial)
                                .cornerRadius(4)
                        }
                    }
                }
            }
            .chartXScale(domain: 0...(max(totalDuration, tickInterval))) // tetap muat semua
            .chartYScale(domain: 50...300)
            .chartXAxis {
                AxisMarks(values: tickValues) { value in
                    AxisGridLine()
                    AxisTick()
                    if let seconds = value.as(Double.self) {
                        AxisValueLabel(String(format: "%.0fs", seconds))
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading)
            }
            .frame(height: 180)
            .padding(.horizontal, 12)
            .animation(.easeInOut(duration: 0.4), value: normalizedSeries)

            if totalDuration > 0 {
                Text("Total Duration: \(String(format: "%.1f", totalDuration)) s")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.leading, 8)
            }
        }
    }
}
