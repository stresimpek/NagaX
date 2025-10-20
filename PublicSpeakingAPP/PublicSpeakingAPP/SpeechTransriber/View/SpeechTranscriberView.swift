//
//  SpeechTranscriberView.swift
//  PublicSpeakingAPP
//
//  Created by Regina Celine Adiwinata on 30/09/25.
//

import SwiftUI
import WhisperKit

struct SpeechTranscriberView: View {
    @StateObject private var vm = SpeechTranscriberViewModel()
    @StateObject private var textAnalyzerVM = TextFrequencyAnalyzerViewModel()
    @StateObject private var intonationAnalyzerVM = IntonationAnalyzerViewModel()
    @StateObject private var tempoVM = TempoViewModel()
    
    @EnvironmentObject var orientationInfo: OrientationInfo

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {

                    // === Header (sama)
                    Text("Whisper Live Transcribe")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    NavigationLink(destination: {
                        SimulationView()
                            .environmentObject(orientationInfo)
                            .navigationBarBackButtonHidden(true)
                            .toolbar(.hidden, for: .navigationBar)
                    }) {
                        Label("Mulai Sesi Latihan", systemImage: "play.display")
                            .font(.headline)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }

                    // === modelStateView (sama)
                    HStack {
                        Image(systemName: "circle.fill")
                            .foregroundStyle(vm.modelState == .loaded ? .green : (vm.modelState == .unloaded ? .red : .yellow))
                            .symbolEffect(.variableColor, isActive: vm.modelState != .loaded && vm.modelState != .unloaded)
                        if vm.modelState == .loading || vm.modelState == .downloading || vm.modelState == .prewarming {
                            ProgressView(value: vm.loadingProgressValue)
                                .progressViewStyle(LinearProgressViewStyle())
                            Text(String(format: "%.0f%%", vm.loadingProgressValue * 100))
                        } else {
                            Text(vm.modelState.description)
                        }
                    }
                    .padding(.horizontal)

                    // === transcriptionView (sama)
                    ScrollViewReader { proxy in
                        ScrollView {
                            VStack(alignment: .leading, spacing: 10) {
                                if vm.enableEagerDecoding {
                                    Text("\(Text(vm.confirmedText).fontWeight(.bold))\(Text(vm.hypothesisText).foregroundColor(.gray))")
                                        .id("bottom")
                                } else {
                                    ForEach(vm.confirmedSegments, id: \.start) { segment in
                                        Text(segment.text).fontWeight(.bold)
                                    }
                                    ForEach(vm.unconfirmedSegments, id: \.start) { segment in
                                        Text(segment.text).foregroundColor(.gray)
                                    }
                                    .id("bottom")
                                }

                                if !vm.isRecording && vm.confirmedText.isEmpty && vm.confirmedSegments.isEmpty {
                                    Text("Tekan tombol rekam untuk memulai...")
                                        .foregroundColor(.gray)
                                        .frame(maxWidth: .infinity, alignment: .center)
                                        .padding(.top, 50)
                                }
                            }
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .onChange(of: vm.confirmedText) { _, _ in proxy.scrollTo("bottom") }
                        .onChange(of: vm.hypothesisText) { _, _ in proxy.scrollTo("bottom") }
                        .onChange(of: vm.unconfirmedSegments) { _, _ in proxy.scrollTo("bottom") }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                    )

                    // === controlsView (sama, dengan binding helper)
                    VStack(spacing: 15) {
                        Toggle("Eager Mode (Latensi Rendah)", isOn: vm.binding(\.enableEagerDecoding))
                            .disabled(vm.isRecording)

                        Button(action: {
                            withAnimation { vm.toggleRecording() }
                        }) {
                            Image(systemName: vm.isRecording ? "stop.circle.fill" : "record.circle")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 70, height: 70)
                                .foregroundColor(vm.modelState == .loaded ? .red : .gray)
                        }
                        .disabled(vm.modelState != .loaded)

                        Text(vm.isRecording ? "Durasi Buffer: \(String(format: "%.1f", vm.bufferSeconds))s" : "Siap Merekam")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    // Tempo bicara
                    if vm.isRecording || tempoVM.wpm > 0 {
                        Divider()
                        TempoView(viewModel: tempoVM)
                            .transition(.opacity.animation(.easeInOut))
                    }

                    // =============== Tambahan: Intonation Graph (di bawah UI Whisper) ===============
                    if !intonationAnalyzerVM.pitchHistory.isEmpty || vm.isRecording {
                        Divider()
                        IntonationGraphView(viewModel: intonationAnalyzerVM)
                            .transition(.opacity.animation(.easeInOut))
                    }

                    // =============== Tambahan: Text Frequency Analysis (di bawah UI Whisper) =======
                    if !textAnalyzerVM.wordFrequencies.isEmpty
                        || !textAnalyzerVM.repeatedWordsInWindow.isEmpty
                        || !textAnalyzerVM.repeatedBigrams.isEmpty
                        || !textAnalyzerVM.repeatedTrigrams.isEmpty {

                        Divider()
                        VStack(alignment: .leading, spacing: 20) {
                            Text("Speech Analysis Results 🔬").font(.title2).bold()

                            AnalysisResultView(
                                title: "📊 Kata yang Sering Diulang (lebih dari 1x)",
                                results: textAnalyzerVM.wordFrequencies
                            )
                            AnalysisResultView(
                                title: "📏 Pengulangan Kata Berdekatan (Jendela 15 kata)",
                                results: textAnalyzerVM.repeatedWordsInWindow
                            )
                            AnalysisResultView(
                                title: "🔗 Frasa yang Diulang (2 Kata)",
                                results: textAnalyzerVM.repeatedBigrams
                            )
                            AnalysisResultView(
                                title: "🔗 Frasa yang Diulang (3 Kata)",
                                results: textAnalyzerVM.repeatedTrigrams
                            )
                        }
                    }
                }
                .padding()
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .onAppear {
            orientationInfo.lockToPortrait()
            vm.textAnalyzerVM = textAnalyzerVM
            vm.intonationAnalyzerVM = intonationAnalyzerVM
            vm.tempoVM = tempoVM
            vm.onAppear() // load model seperti di ContentView.onAppear
        }
        // Fallback non-invasif untuk trigger text analyzer saat teks final/hypothesis berubah
        .onChange(of: vm.confirmedText) { newVal in
            let liveText = newVal + vm.hypothesisText
            if !liveText.isEmpty {
                textAnalyzerVM.analyze(text: liveText)
                tempoVM.updateTempo(text: liveText, duration: vm.bufferSeconds)
            }
        }
        .onChange(of: vm.hypothesisText) { hypo in
            let liveText = vm.confirmedText + hypo
            if !liveText.isEmpty {
                textAnalyzerVM.analyze(text: liveText)
                tempoVM.updateTempo(text: liveText, duration: vm.bufferSeconds)
            }
        }

        .onChange(of: vm.unconfirmedSegments) { _ in
            let text = vm.confirmedSegments.map { $0.text }.joined() + vm.unconfirmedSegments.map { $0.text }.joined()
            if !text.isEmpty {
                textAnalyzerVM.analyze(text: text)
                tempoVM.updateTempo(text: text, duration: vm.bufferSeconds)
            }
        }

        .onChange(of: vm.confirmedSegments) { _ in
            let text = vm.confirmedSegments.map { $0.text }.joined() + vm.unconfirmedSegments.map { $0.text }.joined()
            if !text.isEmpty {
                textAnalyzerVM.analyze(text: text)
                tempoVM.updateTempo(text: text, duration: vm.bufferSeconds)
            }
        }
    }
}


// MARK: - Subview untuk menampilkan hasil analisis
struct AnalysisResultView: View {
    let title: String
    let results: [String: Int]

    var body: some View {
        if !results.isEmpty {
            VStack(alignment: .leading) {
                Text(title).font(.headline)
                ForEach(results.sorted(by: { $0.value > $1.value }), id: \.key) { (item, count) in
                    HStack {
                        Text("'\(item)'")
                            .bold()
                        Spacer()
                        Text("\(count) kali")
                            .foregroundStyle(.secondary)
                    }
                    .font(.subheadline)
                    .padding(.top, 2)
                }
            }
            .padding()
            .background(Color(UIColor.systemGray6))
            .cornerRadius(8)
        }
    }
}
