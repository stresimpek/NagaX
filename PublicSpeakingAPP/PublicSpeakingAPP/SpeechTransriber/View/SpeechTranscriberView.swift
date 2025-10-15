//
//  SpeechTranscriberView.swift
//  PublicSpeakingAPP
//
//  Created by Regina Celine Adiwinata on 30/09/25.
//

import SwiftUI

struct SpeechTranscriberView: View {
    // MARK: - Buat instance kedua ViewModel
    @StateObject private var speechVM = SpeechTranscriberViewModel()
    @StateObject private var textAnalyzerVM = TextFrequencyAnalyzerViewModel()
    @StateObject private var intonationAnalyzerVM = IntonationAnalyzerViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // ... (bagian Controls tidak berubah) ...
                HStack(spacing: 8) {
                    Circle()
                        .fill(speechVM.isRecording ? Color.green : Color.gray)
                        .frame(width: 10, height: 10)
                    Text(speechVM.isRecording ? "Listening…" : "Idle")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 12) {
                    Button {
                        speechVM.startLiveTranscription()
                    } label: {
                        Label("Start Live Transcription", systemImage: "mic.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(speechVM.isRecording || !speechVM.canRecord)

                    Button {
                        speechVM.stopLiveTranscription()
                    } label: {
                        Label("Stop", systemImage: "stop.fill")
                    }
                    .buttonStyle(.bordered)
                    .disabled(!speechVM.isRecording)
                }

                if let error = speechVM.errorMessage {
                    Text(error)
                        .foregroundStyle(.red).font(.footnote)
                }

                // MARK: - Transcript Display
                VStack(alignment: .leading) {
                    Text("Transcript").font(.headline)
                    Text(speechVM.transcript.isEmpty ? "Transcript will appear here..." : speechVM.transcript)
                        .frame(maxWidth: .infinity, minHeight: 100, alignment: .topLeading)
                        .padding()
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(8)
                }
                
                if !intonationAnalyzerVM.pitchHistory.isEmpty || speechVM.isRecording {
                    IntonationGraphView(viewModel: intonationAnalyzerVM)
                        .transition(.opacity.animation(.easeInOut))
                }

                // MARK: - Tampilkan Hasil Analisis
                if !textAnalyzerVM.wordFrequencies.isEmpty || !textAnalyzerVM.repeatedWordsInWindow.isEmpty || !textAnalyzerVM.repeatedBigrams.isEmpty {
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 20) {
                        Text("Speech Analysis Results 🔬")
                            .font(.title2).bold()

                        // 1. Hasil Frekuensi
                        AnalysisResultView(
                            title: "📊 Kata yang Sering Diulang (lebih dari 1x)",
                            results: textAnalyzerVM.wordFrequencies
                        )
                        
                        // 2. Hasil Analisis Jarak
                        AnalysisResultView(
                            title: "📏 Pengulangan Kata Berdekatan (Jendela 15 kata)",
                            results: textAnalyzerVM.repeatedWordsInWindow
                        )

                        // 3. Hasil N-Gram
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
        .onAppear {
            // MARK: - Hubungkan kedua ViewModel
            speechVM.textAnalyzerVM = textAnalyzerVM
            speechVM.intonationAnalyzerVM = intonationAnalyzerVM
            speechVM.requestAuthorization()
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
