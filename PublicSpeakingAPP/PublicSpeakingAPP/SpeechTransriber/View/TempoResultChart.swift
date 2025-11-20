//
//  TempoResultChart.swift
//  PublicSpeakingAPP
//
//  Created by Feby Agatha Christie Kurniawan on 10/11/25.
//

import SwiftUI
import Charts
import AVFoundation

struct TempoResultChart: View {
    let tempoSeries: [TempoPoint]
    let fixedDuration: Double
    
    @EnvironmentObject var whisperKitVM: SpeechTranscriberViewModel
    @StateObject private var audioPlayerVM = AudioPlayerService()
    
    @State private var cursorTime: Double = 0.0
    @State private var isDragging: Bool = false
    
    private let idealMin: Double = 100.0
    private let idealMax: Double = 140.0
    private let cukupMin: Double = 80.0
    private let cukupMax: Double = 160.0
    private let maxY: Double = 200.0
    
    private var chartData: [TempoPoint] {
        guard let t0 = tempoSeries.first?.time else { return [] }
        var newData = tempoSeries.map { TempoPoint(time: $0.time - t0, wpm: min($0.wpm, maxY)) }
        
        if let last = newData.last, last.time < fixedDuration {
            newData.append(TempoPoint(time: fixedDuration, wpm: last.wpm))
        }
        return newData
    }

    private var xDomain: ClosedRange<Double> { 0...max(0.001, fixedDuration) }

    private func formatMMSS(_ seconds: Double) -> String {
        guard seconds.isFinite && seconds >= 0 else { return "0:00" }
        let s = Int(seconds.rounded())
        let m = s / 60
        let r = s % 60
        return String(format: "%d:%02d", m, r)
    }
    
    private func clampToDomain(_ x: Double) -> Double {
        min(max(0, x), fixedDuration)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            
            Chart {
                let lastT = max(fixedDuration, 1.0)

                RectangleMark(
                    xStart: .value("s0", 0), xEnd: .value("s1", lastT),
                    yStart: .value("y0", 0), yEnd: .value("y1", cukupMin)
                )
                .foregroundStyle(.shadowDisabled.opacity(0.1))
                .annotation(position: .overlay, alignment: .center) {
                    Text("LAMBAT")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.textGrey.opacity(0.9))
                }
                
                RectangleMark(
                    xStart: .value("s0", 0), xEnd: .value("s1", lastT),
                    yStart: .value("y0", cukupMin), yEnd: .value("y1", idealMin)
                )
                .foregroundStyle(.lightTurqoise.opacity(0.5))
                .annotation(position: .overlay, alignment: .center) {
                    Text("TENANG")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundStyle(.turqoise.opacity(0.9))
                }
                
                RectangleMark(
                    xStart: .value("s0", 0), xEnd: .value("s1", lastT),
                    yStart: .value("y0", idealMin), yEnd: .value("y1", idealMax)
                )
                .foregroundStyle(.shadowTurqoise2)
                .annotation(position: .overlay, alignment: .center) {
                    Text("NORMAL")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.darkTurqoise.opacity(0.8))
                }

                RectangleMark(
                    xStart: .value("s0", 0), xEnd: .value("s1", lastT),
                    yStart: .value("y0", idealMax), yEnd: .value("y1", cukupMax)
                )
                .foregroundStyle(.lightTurqoise.opacity(0.5))
                .annotation(position: .overlay, alignment: .center) {
                    Text("ENERGIK")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundStyle(.turqoise.opacity(0.9))
                }
                
                RectangleMark(
                    xStart: .value("s0", 0), xEnd: .value("s1", lastT),
                    yStart: .value("y0", cukupMax), yEnd: .value("y1", maxY)
                )
                .foregroundStyle(.shadowDisabled.opacity(0.1))
                .annotation(position: .overlay, alignment: .center) {
                    Text("CEPAT")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.textGrey.opacity(0.9))
                }

                ForEach(chartData) { p in
                    LineMark(
                        x: .value("Time (s)", p.time),
                        y: .value("WPM", p.wpm)
                    )
                    .interpolationMethod(.monotone)
                    .foregroundStyle(.blue)
                }
                
                RuleMark(x: .value("Cursor", cursorTime))
                    .foregroundStyle(isDragging ? .red : .red.opacity(0.8))
                    .lineStyle(.init(lineWidth: 2))
                    .annotation(position: .top) {
                        Text(formatMMSS(cursorTime))
                            .font(.caption2).padding(4)
                            .background(.white, in: Capsule())
                            .shadow(radius: 1)
                    }
            }
            .transaction { $0.animation = nil }
            .chartYAxis {
                AxisMarks {
                }
            }
            .chartXAxis {
                AxisMarks { value in
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel {
                        if let t = value.as(Double.self) {
                            Text("\(Int(t))s")
                                .font(.caption)
                        }
                    }
                }
            }
            .chartXScale(domain: xDomain)
            .chartYScale(domain: 0...maxY)
            .frame(height: 180)
            .padding(.horizontal, 12)
            .chartOverlay { proxy in
                GeometryReader { geo in
                    let plotFrame = geo[proxy.plotAreaFrame]
                    Rectangle()
                        .fill(.clear)
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    isDragging = true
                                    let xInPlot = value.location.x - plotFrame.origin.x
                                    if let t: Double = proxy.value(atX: xInPlot) {
                                        cursorTime = clampToDomain(t)
                                    }
                                }
                                .onEnded { value in
                                    isDragging = false
                                    let xInPlot = value.location.x - plotFrame.origin.x
                                    if let t: Double = proxy.value(atX: xInPlot) {
                                        let finalTime = clampToDomain(t)
                                        cursorTime = finalTime
                                        if let url = whisperKitVM.savedRecordingURL {
                                            audioPlayerVM.play(from: url, startAt: finalTime)
                                            if !audioPlayerVM.isPlaying { audioPlayerVM.pause() }
                                        }
                                    }
                                }
                        )
                }
            }
            .padding(.vertical, 24)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Rekaman Audio")
                    .font(.subheadline)
                    .bold()
                    .foregroundStyle(Color(.baseColorBrown))
                
                HStack(spacing: 12) {
                    Button {
                        if let url = whisperKitVM.savedRecordingURL {
                            if audioPlayerVM.isPlaying {
                                audioPlayerVM.pause()
                            } else {
                                audioPlayerVM.play(from: url, startAt: cursorTime)
                            }
                        }
                    } label: {
                        Image(systemName: audioPlayerVM.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 18, weight: .bold))
                            .padding(10)
                            .foregroundColor(Color(.baseColorBrown))

                    }
                    ZStack{
                        GeometryReader { geo in
                            let width = geo.size.width
                            let safeDuration = max(fixedDuration, 0.001)
                            let progress = CGFloat(cursorTime / safeDuration)
                            let clampedProgress = max(0, min(progress, 1.0))
                            
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color.secondary.opacity(0.25))
                                    .frame(height: 6)
                                
                                Capsule()
                                    .fill(Color.brown)
                                    .frame(width: width * clampedProgress, height: 6)
                            }
                            .contentShape(Rectangle())
                            .gesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { value in
                                        isDragging = true
                                        let percentage = value.location.x / width
                                        let newTime = Double(percentage) * safeDuration
                                        cursorTime = clampToDomain(newTime)
                                    }
                                    .onEnded { value in
                                        isDragging = false
                                        let percentage = value.location.x / width
                                        let finalTime = clampToDomain(Double(percentage) * safeDuration)
                                        cursorTime = finalTime
                                        
                                        if let url = whisperKitVM.savedRecordingURL {
                                            audioPlayerVM.play(from: url, startAt: finalTime)
                                            if !audioPlayerVM.isPlaying { audioPlayerVM.pause() }
                                        }
                                    }
                            ).frame(maxHeight: .infinity, alignment: .center)
                        }
                    }
                    .frame(height: 20)
                }
            }
            .padding(.horizontal, 16)
        }
        .onAppear {
            cursorTime = 0
        }
        .onReceive(audioPlayerVM.$currentTime) { t in
            if audioPlayerVM.isPlaying && !isDragging {
                withAnimation(.linear(duration: 0.1)) {
                    cursorTime = clampToDomain(t)
                }
            }
        }
        .onDisappear {
            audioPlayerVM.pause()
        }
    }
}

