//
//  ContentView.swift
//  PublicSpeakingAPP
//
//  Created by Regina Celine Adiwinata on 30/09/25.
//

import SwiftUI
import Charts

enum ActiveTab {
    case intonasi, kataPengisi, tempo
    case transkrip
}

struct TempoPoint: Identifiable {
    let id = UUID()
    let time: Double
    let wpm: Double
}

struct EvaluationView: View {
    
    @State private var selectedTab: ActiveTab = .tempo
    @Namespace private var tabAnimation
    
    let result: EvaluationModel
    let fullTranscript: String
    
    @EnvironmentObject var whisperKitVM: SpeechTranscriberViewModel
    let textAnalyzerVM: TextFrequencyAnalyzerViewModel?
    let intonationAnalyzerVM: IntonationAnalyzerViewModel?
    let tempoVM: TempoViewModel?
    let fillerWordVM: FillerWordViewModel?
    let settings: PracticeSettings
    let onBack: () -> Void
    let onNext: (PracticeSettings) -> Void
    
    init(
        result: EvaluationModel,
        textAnalyzerVM: TextFrequencyAnalyzerViewModel? = nil,
        intonationAnalyzerVM: IntonationAnalyzerViewModel? = nil,
        tempoVM: TempoViewModel? = nil,
        fillerWordVM: FillerWordViewModel? = nil,
        fullTranscript: String,
        settings: PracticeSettings,
        onBack: @escaping () -> Void,
        onNext: @escaping (PracticeSettings) -> Void
    ) {
        self.result = result
        self.textAnalyzerVM = textAnalyzerVM
        self.intonationAnalyzerVM = intonationAnalyzerVM
        self.tempoVM = tempoVM
        self.fillerWordVM = fillerWordVM
        self.fullTranscript = fullTranscript
        self.settings = settings
        self.onBack = onBack
        self.onNext = onNext
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                
                FeedbackView(feedback: result.aiFeedback)
                ScoreCardView(result: result)
                
                CustomTabBarView(selectedTab: $selectedTab, animation: tabAnimation)
                
                VStack {
                    switch selectedTab {
                    case .intonasi:
                        VStack(alignment: .leading, spacing: 8) {
                            ScrollView {                          
                                Text("Grafik Intonasi (StdDev: \(result.intonationStdDev, specifier: "%.2f"))")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)

                                IntonationResultChart(pitchSeries: result.pitchSeries)
                                    .frame(height: 220)
                            
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    case .kataPengisi:
                        Text("Detail Kata Pengisi (Total: \(result.fillerWordTotalCount))")
                            .frame(height: 350)
                    case .tempo:
                        Text("Grafik Tempo (Avg: \(result.tempoWPM, specifier: "%.0f") WPM)")
                            .frame(height: 350)
                    case .transkrip:
                        VStack(alignment: .leading) {
                            Text("Transkrip Lengkap")
                                .font(.headline)
                                .padding(.bottom, 5)
                            
                            ScrollView {
                                // 4. KODE INI SEKARANG BERFUNGSI SEMPURNA
                                // (Karena 'whisperKitVM' didapat dari @EnvironmentObject)
                                if !whisperKitVM.finalizedStyledTranscript.description.isEmpty {
                                    Text(whisperKitVM.finalizedStyledTranscript)
                                        .font(.system(.body, design: .serif))
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding()
                                } else {
                                    // Fallback
                                    Text(fullTranscript.isEmpty ? "Tidak ada transkrip yang terekam." : fullTranscript)
                                        .font(.system(.body, design: .serif))
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding()
                                }
                            }
                            .frame(height: 350)
                            .background(Color(UIColor.secondarySystemBackground))
                            .cornerRadius(10)
                        }
                    }
                }
                .padding(.horizontal)
                
                Spacer()
            }
        }
        .safeAreaInset(edge: .bottom) {
            FooterButtonsView(
                onBack: self.onBack,
                onNext: {
                    self.onNext(self.settings)
                    whisperKitVM.resetState()
                    tempoVM?.clearResults()
                    intonationAnalyzerVM?.clearResults()
                    textAnalyzerVM?.clearResults()
                    fillerWordVM?.clearResults()
                }
            )
            .background(.bar)
        }
        .background(Color(.systemGroupedBackground))
    }
}

struct FeedbackView: View {
    let feedback: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "bird.fill")
                .font(.system(size: 80))
                .foregroundColor(.black.opacity(0.9))
                .padding(.leading)
                .padding(.top, 10)

            Text(feedback)
                .font(.callout)
                .padding()
                .background(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.gray, lineWidth: 1)
                )
                .padding(.trailing)
        }
        .padding(.top)
    }
}

struct ScoreCardView: View {
    let result: EvaluationModel

    var body: some View {
        HStack(spacing: 20) {
            VStack {
                Text("Nilai")
                    .font(.headline)
                ZStack {
                    Circle()
                        .stroke(Color.red, lineWidth: 5)
                        .frame(width: 60, height: 60)
                    Text(result.overallGrade)
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.red)
                }
                Text(result.overallGrade == "D" ? "GAGAL" : "LULUS")
                    .font(.caption.weight(.bold))
                    .foregroundColor(.red)
            }
            .padding(.leading)
            
            Rectangle()
                .fill(Color.gray.opacity(0.5))
                .frame(width: 1, height: 100)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Intonasi: \(result.intonationFeedback)")
                Text("Tempo: \(result.tempoWPM, specifier: "%.0f") wpm (\(result.tempoFeedback))")
                Text("Filler words: \(result.fillerWordTotalCount)")
                Text("Kontak mata: \(result.eyeContactFeedback)")
            }
            .font(.subheadline)
            
            Spacer()
        }
        .padding()
        .background(Color.white)
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.gray.opacity(0.5), lineWidth: 1)
        )
        .padding(.horizontal)
    }
}

struct CustomTabBarView: View {
    @Binding var selectedTab: ActiveTab
    var animation: Namespace.ID
    
    var body: some View {
        HStack(spacing: 20) {
            TabBarButton(title: "Intonasi", tab: .intonasi, selectedTab: $selectedTab, animation: animation)
            TabBarButton(title: "Kata Pengisi", tab: .kataPengisi, selectedTab: $selectedTab, animation: animation)
            TabBarButton(title: "Tempo", tab: .tempo, selectedTab: $selectedTab, animation: animation)
            TabBarButton(title: "Transkrip", tab: .transkrip, selectedTab: $selectedTab, animation: animation)
            Spacer()
        }
        .padding(.horizontal)
    }
}

struct TabBarButton: View {
    let title: String
    let tab: ActiveTab
    @Binding var selectedTab: ActiveTab
    var animation: Namespace.ID
    
    var isSelected: Bool { selectedTab == tab }
    
    var body: some View {
        Button(action: {
            withAnimation(.spring()) {
                selectedTab = tab
            }
        }) {
            VStack(spacing: 4) {
                Text(title)
                    .fontWeight(isSelected ? .bold : .medium)
                    .foregroundColor(isSelected ? .primary : .gray)
                
                if isSelected {
                    Rectangle()
                        .fill(Color.blue)
                        .frame(height: 3)
                        .matchedGeometryEffect(id: "underline", in: animation)
                } else {
                    Rectangle()
                        .fill(Color.clear)
                        .frame(height: 3)
                }
            }
        }
    }
}

struct KataPengisiView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            WaveformEntryView(time: "02:30 - 03:00", fillerWord: "um...")
            WaveformEntryView(time: "03:30 - 04:00", fillerWord: "eh...")
        }
        .padding(.vertical)
    }
}

struct WaveformEntryView: View {
    let time: String
    let fillerWord: String
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(time)
                .font(.caption)
                .foregroundColor(.gray)
                .padding(.bottom, 5)
            
            VStack {
                WaveformLineView(text: nil)
                WaveformLineView(text: fillerWord)
                WaveformLineView(text: nil)
            }
        }
    }
}

struct WaveformLineView: View {
    let text: String?
    
    var body: some View {
        Image(systemName: "waveform")
            .font(.system(size: 24, weight: .ultraLight))
            .foregroundColor(.gray)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(alignment: .leading) {
                if let text = text {
                    Text(text)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .background(Color.black.opacity(0.7))
                        .foregroundColor(.white)
                        .cornerRadius(4)
                        .offset(x: 100)
                }
            }
    }
}


struct FooterButtonsView: View {
    @Environment(\.dismiss) var dismiss
    
    let onBack: () -> Void
    let onNext: () -> Void
    
    var body: some View {
        HStack(spacing: 15) {
            ButtonComponent(text: "Latihan Lagi", action: onNext)
            ButtonComponent(text: "Selesai", action: onBack)
        }
        .padding()
    }
}
