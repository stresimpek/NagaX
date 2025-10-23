//
//  SettingsView.swift
//  PublicSpeakingAPP
//
//  Created by Regina Celine Adiwinata on 22/10/25.
//

import SwiftUI

struct SettingsView: View {
    // Controls
    @EnvironmentObject private var whisperKitVM: SpeechTranscriberViewModel
    @EnvironmentObject private var textAnalyzerVM: TextFrequencyAnalyzerViewModel
    @EnvironmentObject private var intonationAnalyzerVM: IntonationAnalyzerViewModel
    @EnvironmentObject private var tempoVM: TempoViewModel
    
    @State private var durationMinutes: Int = 5
    @State private var distractionLevel: Double = 0.0
    @State private var enableQnA: Bool = false
    @State private var randomTopic: Bool = false
    
    let onBack: () -> Void
    let onNext: () -> Void

    // Aspect options
    private let aspectOptions: [AspectOption] = [
        .init(title: "Intonasi",     systemImage: "waveform"),
        .init(title: "Filler Words", systemImage: "text.badge.plus"),
        .init(title: "Tempo",        systemImage: "metronome"),
        .init(title: "Kontak Mata",  systemImage: "eye")
    ]

    // Selection state (id -> Bool)
    @State private var selectedAspects: Set<AspectOption> = []

    var body: some View {
        VStack(spacing: 0) {
            SettingsHeader(
                title: "Pilih tempat presentasimu",
                onBack: onBack,
                onNext: onNext
            )

            HStack(alignment: .top, spacing: 20) {
                // Left: room preview
                RoomPreview()
                    .frame(maxWidth: 280)
                    .padding(.leading, 12)

                // Right: controls
                VStack(alignment: .leading, spacing: 16) {

                    // Durasi
                    HStack(alignment: .center) {
                        Text("Durasi")
                            .font(.headline)
//                        Spacer()
                        // “5 menit” pill
                        Text("\(durationMinutes) menit")
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(.gray.opacity(0.25))
                            .clipShape(Capsule())
                    }

                    // Pilihan durasi cepat (opsional)
//                    HStack(spacing: 8) {
//                        ForEach([3,5,7,10], id:\.self) { m in
//                            Button {
//                                durationMinutes = m
//                            } label: {
//                                Text("\(m)m")
//                                    .padding(.horizontal, 10)
//                                    .padding(.vertical, 6)
//                            }
//                            .background(m == durationMinutes ? .blue.opacity(0.2) : .gray.opacity(0.15))
//                            .clipShape(Capsule())
//                        }
//                    }

                    // Distraksi
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Distraksi").font(.headline)
                            VStack(spacing: 4) {
                                Slider(value: $distractionLevel, in: 0...2, step: 1)
                                    .tint(.blue)
                                    .onChange(of: distractionLevel) { v, i in
                                        distractionLevel = v.rounded()   // paksa ke 0/1/2
                                    }

                                // Label di bawah track
                                HStack {
                                    Text("sedikit")
                                    Spacer()
                                    Text("sedang")
                                    Spacer()
                                    Text("banyak")
                                }
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.vertical, 4)

                    // Toggles
                    HStack(spacing: 24) {
                        Toggle("QnA", isOn: $enableQnA)
                            .toggleStyle(.switch)
                        Toggle("Random Topik", isOn: $randomTopic)
                            .toggleStyle(.switch)
                    }

                    Divider().padding(.vertical, 4)

                    // Aspek yang dievaluasi
                    Text("Aspek yang dievaluasi")
                        .font(.headline)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(aspectOptions) { opt in
                                AspectCheckTile(
                                    option: opt,
                                    isSelected: Binding(
                                        get: { selectedAspects.contains(opt) },
                                        set: { newVal in
                                            if newVal { selectedAspects.insert(opt) }
                                            else { selectedAspects.remove(opt) }
                                        }
                                    )
                                )
                            }
                        }
                        .padding(.vertical, 4)
                    }

                    Spacer(minLength: 0)
                }
                .padding(.trailing, 16)
            }
            .padding(.vertical, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.white)
    }
}
