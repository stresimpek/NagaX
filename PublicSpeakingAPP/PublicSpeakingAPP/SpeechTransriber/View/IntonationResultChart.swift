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
    @EnvironmentObject var whisperKitVM: SpeechTranscriberViewModel
    @StateObject private var audioPlayerVM = AudioPlayerService()
    
    @State private var cursorTime: Double = 0.0
        @State private var isDragging: Bool = false

    private let bandLow: Double = 18.0
    private let bandHigh: Double = 35.0
    private let maxY: Double = 50.0

    var windowSeconds: Double = 10.0

    private var totalDuration: Double { normalized.last?.time ?? 0 }

    // Normalisasi waktu mulai dari 0
    private var normalized: [PitchPoint] {
        guard let t0 = pitchSeries.first?.time else { return pitchSeries }
        return pitchSeries.map { .init(time: $0.time - t0, pitch: $0.pitch) }
    }
    
    @State private var lockedXMax: Double = 0
    @State private var xLocked: Bool = false
    private var liveXMax: Double { max(totalDuration, audioPlayerVM.duration) }
    private var xMax: Double { xLocked ? lockedXMax : liveXMax }
    // Gantilah liveXMax & xMax menjadi totalX yang jelas sumbernya
    private var durationFromAudio: Double { audioPlayerVM.duration }
    private var durationFromData:  Double { totalDuration }
    private var totalX: Double { max(durationFromAudio, durationFromData) } // domain pakai ini

    // Domain X JANGAN pakai max(..., tickStepSeconds)
//    private var xDomain: ClosedRange<Double> { 0...max(0.0, totalX) }

    // ⬇️ Tambahkan alias yang jelas untuk domain visual
    private var visualXMax: Double { totalDuration }

    // ⬇️ Domain X untuk chart (bukan totalX lagi)
    private var xDomain: ClosedRange<Double> { 0...max(0.0, visualXMax) }


    private func clampToDomain(_ x: Double) -> Double {
        min(max(0, x), xMax)
    }

    private var tickStepSeconds: Double {
        switch visualXMax {
        case ...15:   return 5
        case ...60:   return 15
        case ...120:  return 30
        case ...300:  return 60
        case ...600:  return 180
        default:      return 300
        }
    }
    
    private func formatMMSS(_ seconds: Double) -> String {
        guard seconds.isFinite && seconds >= 0 else { return "0:00" }
        let s = Int(seconds.rounded())
        let m = s / 60
        let r = s % 60
        return String(format: "%d:%02d", m, r)
    }


    // 2) Step sampling data (JANGAN samakan dengan tick)
    private let sampleStepSeconds: Double = 1.0  // atau 0.5 untuk lebih halus

    // 3) Rolling std pakai sampleStepSeconds + paksa titik terakhir
    private var rollingStd: [PitchPoint] {
        guard totalDuration > 0 else { return [] }
        var out: [PitchPoint] = []
        var t = 0.0
        while t <= totalDuration {
            let windowStart = max(0.0, t - windowSeconds)
            let window = normalized.filter { $0.time >= windowStart && $0.time <= t }.map(\.pitch)

            if window.count >= 2 {
                let mean = window.reduce(0,+) / Double(window.count)
                let varSum = window.reduce(0) { $0 + pow($1 - mean, 2) }
                let std = sqrt(varSum / Double(window.count))
                out.append(.init(time: t, pitch: std))
            } else if let last = out.last {
                // fallback: pakai nilai terakhir agar garis tidak putus
                out.append(.init(time: t, pitch: last.pitch))
            }
            t += sampleStepSeconds
        }

        // Paksa titik persis di totalDuration bila belum ada (pakai epsilon)
        let eps = 1e-3
        if let lastT = out.last?.time, abs(lastT - totalDuration) > eps {
            let windowStart = max(0.0, totalDuration - windowSeconds)
            let window = normalized.filter { $0.time >= windowStart && $0.time <= totalDuration }.map(\.pitch)
            if window.count >= 2 {
                let mean = window.reduce(0,+) / Double(window.count)
                let varSum = window.reduce(0) { $0 + pow($1 - mean, 2) }
                let std = sqrt(varSum / Double(window.count))
                out.append(.init(time: totalDuration, pitch: std))
            } else if let last = out.last {
                out.append(.init(time: totalDuration, pitch: last.pitch))
            } else {
                out.append(.init(time: totalDuration, pitch: 0))
            }
        }
        return out
    }


    // Pakai step ini juga untuk sampling rollingStd biar konsisten tampilannya
    private var dynamicStepSeconds: Double { tickStepSeconds }

    // Label sumbu X yang adaptif (pakai m: ss untuk rentang pendek, atau Xm)
    private func xAxisLabel(_ value: Double) -> String {
        let v = max(0, value)
        if tickStepSeconds < 60 {
            // Per detik: tampilkan detik saja (0s, 15s, 30s)
            return "\(Int(v))s"
        } else {
            // Per menit/menit-jamak
            let minutes = Int(v) / 60
            // Kalau step 60 detik, tampilkan "1m, 2m, ..."
            if tickStepSeconds == 60 {
                return "\(minutes)m"
            } else {
                // Untuk 3m atau 5m, tetap "3m", "6m", dst (clear & ringkas)
                return "\(minutes)m"
            }
        }
    }

    // Smooth pakai EMA biar garis halus
    private var smoothedRollingStd: [PitchPoint] {
        let alpha = 0.3
        var ema: Double?
        return rollingStd.map { p in
            let v = (ema == nil) ? p.pitch : (alpha * p.pitch + (1 - alpha) * ema!)
            ema = v
            return .init(time: p.time, pitch: min(v, maxY))
        }
    }
    
    private var displaySeries: [PitchPoint] {
        var s = smoothedRollingStd
        if let last = s.last, visualXMax > last.time {
            // tarik horizontal sampai ujung domain visual
            s.append(.init(time: visualXMax, pitch: last.pitch))
        } else if s.isEmpty, visualXMax > 0 {
            // fallback kalau datanya kosong tapi ada domain
            s = [.init(time: 0, pitch: 0), .init(time: visualXMax, pitch: 0)]
        }
        return s
    }



    private func formatClock(_ sec: Double) -> String {
        let s = Int(sec.rounded())
        let m = s / 60
        let r = s % 60
        return m > 0 ? String(format: "%dm %02ds", m, r) : "\(r)s"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Pitch Variability (Std Dev over time)")
                .font(.headline)
                .padding(.leading, 8)
            
            Chart {
                // Background bands
                if visualXMax > 0 {
                    RectangleMark(xStart: .value("s0", 0), xEnd: .value("s1", visualXMax),
                                  yStart: .value("y0", 0), yEnd: .value("y1", bandLow))
                    .foregroundStyle(.orange.opacity(0.10))

                    RectangleMark(xStart: .value("s0", 0), xEnd: .value("s1", visualXMax),
                                  yStart: .value("y0", bandLow), yEnd: .value("y1", bandHigh))
                    .foregroundStyle(.green.opacity(0.10))

                    RectangleMark(xStart: .value("s0", 0), xEnd: .value("s1", visualXMax),
                                  yStart: .value("y0", bandHigh), yEnd: .value("y1", maxY))
                    .foregroundStyle(.yellow.opacity(0.10))
                }
                
                ForEach(displaySeries) { p in
                    LineMark(
                        x: .value("Time", p.time),
                        y: .value("Std Dev", p.pitch)
                    )
                    .interpolationMethod(.monotone)
                }
                
                RuleMark(x: .value("Cursor", clampToDomain(cursorTime)))
                    .foregroundStyle(isDragging ? .red : .red.opacity(0.8))
                    .lineStyle(.init(lineWidth: 2))
                    .annotation(position: .top) {
                        Text(formatClock(cursorTime))
                            .font(.caption2).padding(4)
                            .background(.white, in: Capsule())
                    }
            }
            .transaction { $0.animation = nil }
            .animation(nil, value: cursorTime)
            .chartYAxis {
                AxisMarks(position: .leading)
            }
            .chartYAxisLabel("Std Dev (pitch)", position: .leading)
            .chartXAxis {
                AxisMarks(values: Array(stride(from: 0.0,
                       to: visualXMax + tickStepSeconds * 0.5,
                       by: tickStepSeconds))) { val in
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel {
                        if let d = val.as(Double.self) { Text(xAxisLabel(d)) }
                    }
                }
            }
            .chartXScale(domain: xDomain, range: .plotDimension(padding: 0))
            .chartYScale(domain: 0...maxY)
            .frame(height: 180)
            .padding(.horizontal, 12)
            .overlay(alignment: .bottomTrailing) {
                Text(formatMMSS(audioPlayerVM.duration)) // tetap durasi audio sesuai request
                    .font(.caption2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(.trailing, 16)
                    .padding(.bottom, 8)
            }

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
                                    if audioPlayerVM.isPlaying { audioPlayerVM.seek(to: cursorTime) }
                                }
                                .onEnded { value in
                                    isDragging = false
                                    let xInPlot = value.location.x - plotFrame.origin.x
                                    if let t: Double = proxy.value(atX: xInPlot) {
                                        cursorTime = clampToDomain(t)
                                    }
                                }
                        )
                }
            }
            
            // === UI player seperti contoh gambar ===
           VStack(alignment: .leading, spacing: 8) {
               Text("Rekaman Audio")
                   .font(.subheadline)
                   .foregroundStyle(.secondary)

               HStack(spacing: 12) {
                   Button {
                       if let url = whisperKitVM.savedRecordingURL {
                           if audioPlayerVM.isPlaying {
                               audioPlayerVM.pause()
                           } else {
                               audioPlayerVM.play(from: url, startAt: cursorTime)
                               cursorTime = clampToDomain(audioPlayerVM.currentTime)
                           }
                       }
                   } label: {
                       Image(systemName: audioPlayerVM.isPlaying ? "pause.fill" : "play.fill")
                           .font(.system(size: 18, weight: .bold))
                           .padding(10)
                           .background(Color.primary.opacity(0.08), in: Circle())
                   }

                   ZStack(alignment: .leading) {
                       GeometryReader { geo in
                           let width = geo.size.width
                           let dur = max(audioPlayerVM.duration, 0.0001) // hindari /0
                           let progress = CGFloat(min(max(audioPlayerVM.currentTime, 0), dur) / dur)
                           Capsule().fill(Color.secondary.opacity(0.25)).frame(height: 6)
                           Capsule().fill(Color.brown)
                               .frame(width: progress * width, height: 6)
                       }
                   }
                   .frame(width: UIScreen.main.bounds.width * 0.65, height: 6) // ukuran kontainer tetap
                   .contentShape(Rectangle())
                   .gesture(
                       DragGesture(minimumDistance: 0)
                           .onChanged { g in
                               let width = UIScreen.main.bounds.width * 0.65
                               let dur = max(audioPlayerVM.duration, 0.0001)
                               let x = min(max(0, g.location.x), width)
                               let ratio = x / width
                               let target = Double(ratio) * dur
                               isDragging = true
                               cursorTime = clampToDomain(target)
                           }
                           .onEnded { _ in
                               isDragging = false
                               if audioPlayerVM.isPlaying { audioPlayerVM.seek(to: cursorTime) }
                           }
                   )

               }
           }
           .padding(.horizontal, 16)
       }
        .onAppear {
            cursorTime = 0
            // Coba baca durasi audio tanpa memutar (biar domain langsung stabil)
            if let url = whisperKitVM.savedRecordingURL {
                let asset = AVURLAsset(url: url)
                let d = asset.duration.seconds
                if d.isFinite, d > 0 {
                    lockedXMax = max(totalDuration, d)
                    xLocked = true
                }
            }
            // Kalau gagal, sementara pakai totalDuration
            if !xLocked {
                lockedXMax = max(totalDuration, 0)
                xLocked = true
            }
        }
        .onReceive(audioPlayerVM.$duration) { d in
            // Kalau belum sempat terkunci di onAppear (misal durasi baru diketahui), kunci sekarang
            if !xLocked, d > 0 {
                lockedXMax = max(totalDuration, d)
                xLocked = true
            }
        }
        .onReceive(audioPlayerVM.$currentTime) { t in
            // update hanya kalau bukan sedang drag manual
            if audioPlayerVM.isPlaying && !isDragging {
                withAnimation(.none) {
                    cursorTime = clampToDomain(t)
                }
            }
        }

       .onDisappear {
           if audioPlayerVM.isPlaying { audioPlayerVM.pause() }
       }
    }
}
