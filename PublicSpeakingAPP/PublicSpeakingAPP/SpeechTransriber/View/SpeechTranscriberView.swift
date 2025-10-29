//
//  SpeechTranscriberView.swift
//  PublicSpeakingAPP
//
//  Created by Regina Celine Adiwinata on 30/09/25.
//
//  Fixed by Gemini on 22/10/25 to remove ViewModel loop.
//

//import SwiftUI
//import WhisperKit
//
//struct SpeechTranscriberView: View {
//    @ObservedObject var whisperKitVM: SpeechTranscriberViewModel
//    
//    let textAnalyzerVM: TextFrequencyAnalyzerViewModel
//    let intonationAnalyzerVM: IntonationAnalyzerViewModel
//    let tempoVM: TempoViewModel
//
//    var body: some View {
//        NavigationStack {
//            ScrollView {
//                VStack(spacing: 20) {
//
//                    Text("Whisper Live Transcribe")
//                        .font(.largeTitle)
//                        .fontWeight(.bold)
//                    
//                    NavigationLink(destination: {
//                        SimulationViewWrapper(
//                            whisperKitVM: whisperKitVM,
//                            textAnalyzerVM: textAnalyzerVM,
//                            intonationAnalyzerVM: intonationAnalyzerVM,
//                            tempoVM: tempoVM
//                        )
//                        .navigationBarBackButtonHidden(true)
//                        .toolbar(.hidden, for: .navigationBar)
//                    }) {
//                        Label("Mulai Sesi Latihan", systemImage: "play.display")
//                            .font(.headline)
//                            .padding()
//                            .frame(maxWidth: .infinity)
//                            .background(Color.blue)
//                            .foregroundColor(.white)
//                            .cornerRadius(12)
//                    }
//
//                    HStack {
//                        Image(systemName: "circle.fill")
//                            .foregroundStyle(whisperKitVM.modelState == .loaded ? .green : (whisperKitVM.modelState == .unloaded ? .red : .yellow))
//                            .symbolEffect(.variableColor, isActive: whisperKitVM.modelState != .loaded && whisperKitVM.modelState != .unloaded)
//                        if whisperKitVM.modelState == .loading || whisperKitVM.modelState == .downloading || whisperKitVM.modelState == .prewarming {
//                            ProgressView(value: whisperKitVM.loadingProgressValue)
//                                .progressViewStyle(LinearProgressViewStyle())
//                            Text(String(format: "%.0f%%", whisperKitVM.loadingProgressValue * 100))
//                        } else {
//                            Text(whisperKitVM.modelState.description)
//                        }
//                    }
//                    .padding(.horizontal)
//
//                    ScrollViewReader { proxy in
//                        ScrollView {
//                            VStack(alignment: .leading, spacing: 10) {
//                                if whisperKitVM.enableEagerDecoding {
//                                    Text("\(Text(whisperKitVM.confirmedText).fontWeight(.bold))\(Text(whisperKitVM.hypothesisText).foregroundColor(.gray))")
//                                        .id("bottom")
//                                } else {
//                                    ForEach(whisperKitVM.confirmedSegments, id: \.start) { segment in
//                                        Text(segment.text).fontWeight(.bold)
//                                    }
//                                    ForEach(whisperKitVM.unconfirmedSegments, id: \.start) { segment in
//                                        Text(segment.text).foregroundColor(.gray)
//                                    }
//                                    .id("bottom")
//                                }
//
//                                if !whisperKitVM.isRecording && whisperKitVM.confirmedText.isEmpty && whisperKitVM.confirmedSegments.isEmpty {
//                                    Text("Tekan tombol rekam untuk memulai...")
//                                        .foregroundColor(.gray)
//                                        .frame(maxWidth: .infinity, alignment: .center)
//                                        .padding(.top, 50)
//                                }
//                            }
//                            .padding()
//                            .frame(maxWidth: .infinity, alignment: .leading)
//                        }
//                        .onChange(of: whisperKitVM.confirmedText) { _, _ in proxy.scrollTo("bottom") }
//                        .onChange(of: whisperKitVM.hypothesisText) { _, _ in proxy.scrollTo("bottom") }
//                        .onChange(of: whisperKitVM.unconfirmedSegments) { _, _ in proxy.scrollTo("bottom") }
//                    }
//                    .frame(minHeight: 200, maxHeight: .infinity)
//                    .background(Color(UIColor.secondarySystemBackground))
//                    .cornerRadius(12)
//                    .overlay(
//                        RoundedRectangle(cornerRadius: 12)
//                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
//                    )
//
//                    VStack(spacing: 15) {
//                        Toggle("Eager Mode (Latensi Rendah)", isOn: whisperKitVM.binding(\.enableEagerDecoding))
//                            .disabled(whisperKitVM.isRecording)
//
//                        Button(action: {
//                            withAnimation { whisperKitVM.toggleRecording(shouldLoop: true) }
//                        }) {
//                            Image(systemName: whisperKitVM.isRecording ? "stop.circle.fill" : "record.circle")
//                                .resizable()
//                                .scaledToFit()
//                                .frame(width: 70, height: 70)
//                                .foregroundColor(whisperKitVM.modelState == .loaded ? .red : .gray)
//                        }
//                        .disabled(whisperKitVM.modelState != .loaded)
//
//                        Text(whisperKitVM.isRecording ? "Durasi Buffer: \(String(format: "%.1f", whisperKitVM.bufferSeconds))s" : "Siap Merekam")
//                            .font(.caption)
//                            .foregroundColor(.secondary)
//                    }
//                    
//                    if whisperKitVM.isRecording || tempoVM.wpm > 0 {
//                        Divider()
//                        TempoView(viewModel: tempoVM)
//                            .transition(.opacity.animation(.easeInOut))
//                    }
//
//                    if !intonationAnalyzerVM.pitchHistory.isEmpty || whisperKitVM.isRecording {
//                        Divider()
//                        IntonationGraphView(viewModel: intonationAnalyzerVM)
//                            .transition(.opacity.animation(.easeInOut))
//                    }
//
//                    if !textAnalyzerVM.wordFrequencies.isEmpty
//                        || !textAnalyzerVM.repeatedWordsInWindow.isEmpty
//                        || !textAnalyzerVM.repeatedBigrams.isEmpty
//                        || !textAnalyzerVM.repeatedTrigrams.isEmpty {
//
//                        Divider()
//                        VStack(alignment: .leading, spacing: 20) {
//                            Text("Speech Analysis Results 🔬").font(.title2).bold()
//
//                            AnalysisResultView(
//                                title: "📊 Kata yang Sering Diulang (lebih dari 1x)",
//                                results: textAnalyzerVM.wordFrequencies
//                            )
//                            AnalysisResultView(
//                                title: "📏 Pengulangan Kata Berdekatan (Jendela 15 kata)",
//                                results: textAnalyzerVM.repeatedWordsInWindow
//                            )
//                            AnalysisResultView(
//                                title: "🔗 Frasa yang Diulang (2 Kata)",
//                                results: textAnalyzerVM.repeatedBigrams
//                            )
//                            AnalysisResultView(
//                                title: "🔗 Frasa yang Diulang (3 Kata)",
//                                results: textAnalyzerVM.repeatedTrigrams
//                            )
//                        }
//                    }
//                }
//                .padding()
//            }
//            .toolbar(.hidden, for: .navigationBar)
//        }
//        .onAppear {
//            whisperKitVM.textAnalyzerVM = textAnalyzerVM
//            whisperKitVM.intonationAnalyzerVM = intonationAnalyzerVM
//            whisperKitVM.tempoVM = tempoVM
//            whisperKitVM.onAppear()
//        }
//    }
//}
//
//
//// MARK: - Subview untuk menampilkan hasil analisis
//struct AnalysisResultView: View {
//    let title: String
//    let results: [String: Int]
//
//    var body: some View {
//        if !results.isEmpty {
//            VStack(alignment: .leading) {
//                Text(title).font(.headline)
//                ForEach(results.sorted(by: { $0.value > $1.value }), id: \.key) { (item, count) in
//                    HStack {
//                        Text("'\(item)'")
//                            .bold()
//                        Spacer()
//                        Text("\(count) kali")
//                            .foregroundStyle(.secondary)
//                    }
//                    .font(.subheadline)
//                    .padding(.top, 2)
//                }
//            }
//            .padding()
//            .background(Color(UIColor.systemGray6))
//            .cornerRadius(8)
//        }
//    }
//}
