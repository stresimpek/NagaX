//
//  IntonationResultChart.swift
//  PublicSpeakingAPP
//
//  Created by Regina Celine Adiwinata on 02/11/25.
//

import SwiftUI
import Charts
import Combine
import AVFoundation

struct PitchPoint: Identifiable, Hashable {
    let id = UUID()
    let time: Double
    let pitch: Double
}

struct IntonationResultChart: View {

    let pitchSeries: [PitchPoint]
    let fixedDuration: Double
    
    @EnvironmentObject var whisperKitVM: SpeechTranscriberViewModel
    @StateObject private var audioPlayerVM = AudioPlayerService()
    
    @State private var cursorTime: Double = 0.0
    @State private var isDragging: Bool = false
    @State private var processedSeries: [PitchPoint] = []

    private let bandLow: Double = 18.0
    private let bandHigh: Double = 35.0
    private let maxY: Double = 50.0
    private let windowSeconds: Double = 10.0
    
    init(pitchSeries: [PitchPoint], fixedDuration: Double = 0) {
        self.pitchSeries = pitchSeries
        self.fixedDuration = fixedDuration
    }

    private var xDomain: ClosedRange<Double> { 0...max(0.001, fixedDuration) }

    private func xAxisLabel(_ value: Double) -> String {
        let v = max(0, value)
        let minutes = Int(v) / 60
        let seconds = Int(v) % 60
        return fixedDuration < 60 ? "\(seconds)s" : String(format: "%d:%02d", minutes, seconds)
    }
    
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
                if fixedDuration > 0 {
                    RectangleMark(
                        xStart: .value("s0", 0),
                        xEnd: .value("s1", fixedDuration),
                        yStart: .value("y0", 0),
                        yEnd: .value("y1", bandLow)
                    )
                    .foregroundStyle(.shadowDisabled.opacity(0.1))
                    .annotation(position: .overlay, alignment: .center) {
                        Text("MONOTON")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundStyle(Color.textGrey.opacity(0.9))
                    }

                    RectangleMark(
                        xStart: .value("s0", 0),
                        xEnd: .value("s1", fixedDuration),
                        yStart: .value("y0", bandLow),
                        yEnd: .value("y1", bandHigh)
                    )
                    .foregroundStyle(.lightTurqoise.opacity(0.5))
                    .annotation(position: .overlay, alignment: .center) {
                        Text("BERDINAMIKA")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundStyle(.turqoise.opacity(0.9))
                    }

                    RectangleMark(
                        xStart: .value("s0", 0),
                        xEnd: .value("s1", fixedDuration),
                        yStart: .value("y0", bandHigh),
                        yEnd: .value("y1", maxY)
                    )
                    .foregroundStyle(.shadowDisabled.opacity(0.1))
                    .annotation(position: .overlay, alignment: .center) {
                        Text("AGAK BERLEBIHAN")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundStyle(Color.textGrey.opacity(0.9))
                    }
                }
                
                RuleMark(y: .value("Limit1", bandLow))
                        .foregroundStyle(.gray.opacity(0.6))
                        .lineStyle(.init(lineWidth: 1, dash: [4]))

                RuleMark(y: .value("Limit2", bandHigh))
                    .foregroundStyle(.gray.opacity(0.6))
                    .lineStyle(.init(lineWidth: 1, dash: [4]))
                
                ForEach(processedSeries) { p in
                    LineMark(
                        x: .value("Time", p.time),
                        y: .value("Std Dev", p.pitch)
                    )
                    .interpolationMethod(.monotone)
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
            .chartYAxis { AxisMarks(position: .leading) }
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

                HStack(alignment: .center, spacing: 12) {
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
                    }.frame(height: 40)
                    
                }
            }
            .padding(.horizontal, 16)
       }
        .onAppear {
            calculateRollingStd()
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
    
    private func calculateRollingStd() {
        guard !pitchSeries.isEmpty, fixedDuration > 0 else {
            self.processedSeries = []
            return
        }
        
        let t0 = pitchSeries.first?.time ?? 0
        let normalized = pitchSeries.map { PitchPoint(time: $0.time - t0, pitch: $0.pitch) }
        
        var out: [PitchPoint] = []
        let step = 0.5
        var t = 0.0
        
        while t <= fixedDuration {
            let windowStart = max(0.0, t - windowSeconds)
            let window = normalized.filter { $0.time >= windowStart && $0.time <= t }.map(\.pitch)

            if window.count >= 2 {
                let mean = window.reduce(0,+) / Double(window.count)
                let varSum = window.reduce(0) { $0 + pow($1 - mean, 2) }
                let std = sqrt(varSum / Double(window.count))
                
                let prev = out.last?.pitch ?? std
                let smoothed = (prev * 0.7) + (std * 0.3)
                
                out.append(PitchPoint(time: t, pitch: min(smoothed, maxY)))
            } else if let last = out.last {
                out.append(PitchPoint(time: t, pitch: last.pitch))
            } else {
                out.append(PitchPoint(time: t, pitch: 0))
            }
            t += step
        }
        self.processedSeries = out
    }
}
