//
//  SimulationView.swift
//  PublicSpeakingAPP
//
//  Created by Jordan on 19/10/25.
//

import SwiftUI
import Combine
import WhisperKit

struct SimulationViewWrapper: View {
    @EnvironmentObject private var whisperKitVM: SpeechTranscriberViewModel
    @EnvironmentObject private var textAnalyzerVM: TextFrequencyAnalyzerViewModel
    @EnvironmentObject private var intonationAnalyzerVM: IntonationAnalyzerViewModel
    @EnvironmentObject private var tempoVM: TempoViewModel
    @EnvironmentObject private var fillerWordVM: FillerWordViewModel
    
    let settings: PracticeSettings
    let onBack: () -> Void
    let onRestartPractice: () -> Void
    let onComplete: (EvaluationModel, String, String) -> Void
    
    var body: some View {
        SimulationView(
            viewModel: SimulationViewModel(
                settings: settings,
                whisperKitVM: whisperKitVM,
                textAnalyzerVM: textAnalyzerVM,
                intonationAnalyzerVM: intonationAnalyzerVM,
                tempoVM: tempoVM,
                fillerWordVM: fillerWordVM
            ),
            onBack: onBack,
            onComplete: onComplete,
            onRestartPractice: onRestartPractice
        )
    }
}

struct SimulationView: View {
    
    @StateObject private var viewModel: SimulationViewModel
    @StateObject private var micMonitor = MicMonitorModal()
    
    let onBack: () -> Void
    let onRestartPractice: () -> Void
    let onComplete: (EvaluationModel, String, String) -> Void
    
//    private var isProcessing: Bool {
//        return !viewModel.isRecording && viewModel.whisperKitVM.isTranscribing
//    }
    
    private var isProcessing: Bool {
        let status = viewModel.whisperKitVM.recordingStatus
        return !viewModel.isRecording
            && viewModel.whisperKitVM.isTranscribing
            && (status == .stopping || status == .stopped)
    }

    
    init(
        viewModel: SimulationViewModel,
        onBack: @escaping () -> Void,
        onComplete: @escaping (EvaluationModel, String, String) -> Void,
        onRestartPractice: @escaping () -> Void
    ) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.onBack = onBack
        self.onComplete = onComplete
        self.onRestartPractice = onRestartPractice
    }
    
    @State private var isOverOneMinutes: Bool = false
    @State private var bannerQueue: [BannerItem] = []
    @State private var currentBanner: BannerItem? = nil
    @State private var hasShownOvertimeBanner = false
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                TeacherRiveView(sim: viewModel)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                    .onChange(of: viewModel.isRecording) { _, newValue in
                        newValue ? micMonitor.startMonitoring() : micMonitor.stopMonitoring()
                    }

                VStack {
                    Group {
                        if isOverOneMinutes {
                            Text("WAKTU HABIS!")
                                .padding()
                                .foregroundColor(.baseColorRed)
                                .frame(height: 42)
                                .background(.coral)
                                .cornerRadius(24)
                                .shadow(color: .lightCoral, radius: 0, x: 0, y: 4)
                        }
                    }
                    .font(.headline)
                    .animation(.easeInOut, value: isOverOneMinutes)
                    .padding(.top, 16)


                    Spacer()

                    HStack {
                        if viewModel.isOvertime {
                            HStack (alignment: .center) {
                                Image(systemName: "alarm")
                                Text(viewModel.formattedTime)
                            }
                            .font(.system(size: 32, weight: .bold, design: .monospaced))
                            .padding(8)
                            .foregroundColor(.baseColorRed)
                            .background(.coral)
                            .cornerRadius(24)
                            .shadow(color: .lightCoral, radius: 0, x: 0, y: 4)
                        } else {
                            HStack (alignment: .center) {
                                Image(systemName: "alarm")
                                Text(viewModel.formattedTime)
                            }
                            .font(.system(size: 32, weight: .bold, design: .monospaced))
                            .padding(8)
                            .foregroundColor(.baseColorBrown)
                            .background(.baseColorWhite)
                            .cornerRadius(24)
                            .shadow(color: .beige, radius: 0, x: 0, y: 4)
                        }
                        Spacer()
                        if viewModel.isRecording {
                            ZStack(alignment: .leading) {
                                AudioVisualizerModalView(micMonitor: micMonitor)
                                    .padding(.leading, 30)
                                    .padding(.trailing, 0)
                                    .frame(width: 280, height: 50)
                                    .frame(alignment: .leading)
                                    .background(Color.black.opacity(0.27))
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                                    .offset(x: 20)
                                
                                MicIconButton(showMicWarning: false)
                            }
                        }
                        Spacer()
                        HStack(spacing: 5) {
                            ButtonComponent(
                                title: viewModel.isRecording ? "STOP REKAM" : "MULAI REKAM",
                                systemImage: viewModel.isRecording ? "stop.circle.fill" : "record.circle",
                                size: .large,
                                kind: .primaryYellow,
                                action: viewModel.toggleRecording
                            )
                            .disabled(viewModel.whisperModelState != .loaded || isProcessing )
                            VStack(alignment: .leading) {
                                if viewModel.whisperModelState != .loaded && !viewModel.isRecording {
                                    Text(viewModel.whisperModelState.description)
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom)
                }
                .zIndex(10)

                if isProcessing {
                    Color.black.opacity(0.5)
                        .ignoresSafeArea()
                        .zIndex(11)
                    ProgressView("Menganalisis...")
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.5)
                        .font(.title3)
                        .foregroundColor(.white)
                        .zIndex(12)
                }
            }
            .overlay(alignment: .top) {
                if let banner = currentBanner {
                    ComponentObjective(
                        text: banner.text,
                        isOvertime: banner.isOvertime
                    ) {
                        advanceBannerQueue()
                    }
                    .id(banner.id)
                }
            }
            .onAppear() {
                setupInitialBanners()
                isOverOneMinutes = false
                hasShownOvertimeBanner = false
            .overlay {
                if viewModel.whisperKitVM.showEarlyStopModal
                {
                                EarlyStopModalView(
                                    onContinue: {
                                        viewModel.resumeAfterEarlyStop()
                                    },
                                    onViewEvaluation: {
                                        viewModel.whisperKitVM.proceedToEvaluationFromModal(loop: false)
                                    }
                                )
                                .transition(.opacity)
                                .zIndex(20)
                            }
// test the EmptyTranscriptModalView
//                {
//                    EmptyTranscriptModalView(
//                        onRestart: {
//                            viewModel.restartAfterEmptyTranscript()
//                        },
//                        onContinue: {
//                            viewModel.resumeAfterEarlyStop()
//                        }
//                    )
//                    .transition(.opacity)
//                    .zIndex(20)
//                }
                
                            
                if viewModel.whisperKitVM.showEmptyTranscriptModal {
                                EmptyTranscriptModalView(
                                    onRestart: {
                                        viewModel.restartAfterEmptyTranscript()
                                    },
                                    onContinue: {
                                        viewModel.resumeAfterEarlyStop()
                                    }
                                )
                                .transition(.opacity)
                                .zIndex(20)
                            }
                }
            .frame(width: geo.size.width, height: geo.size.height)
            .onDisappear { viewModel.cleanup() }
            .onReceive(viewModel.$isAnalysisComplete) { isComplete in
                if isComplete {
                    if let result = viewModel.evaluationResult {
                        print("Evaluation result FOUND. Calling onComplete...")
                        onComplete(
                            result,
                            viewModel.finalTranscript,
                            viewModel.whisperKitVM.sentenceAnalysisResult
                        )
                    } else {
                        onBack()
                    }
                }
            }
            .onReceive(viewModel.$isOverOneMinuteTrigger) { isOverOneMinute in
                if isOverOneMinute {
                    isOverOneMinutes = !isOverOneMinutes
                }
            }
            .onReceive(viewModel.$isOvertimeTrigger) { isOver in
                if isOver && !hasShownOvertimeBanner {
                    hasShownOvertimeBanner = true
                    enqueueBanner(
                        text: "Sudah lewat durasi. Cepat selesaikan presentasimu!",
                        isOvertime: true
                    )
                }
            }
            .navigationBarBackButtonHidden(true)
            .task {
                viewModel.whisperKitVM.resetState()
                viewModel.textAnalyzerVM.clearResults()
                viewModel.intonationAnalyzerVM.clearResults()
                viewModel.tempoVM.clearResults()
            }
            .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") { viewModel.errorMessage = nil }
            } message: {
                if let error = viewModel.errorMessage { Text(error) }
            }
        }
    }
    
    private func setupInitialBanners() {
        enqueueBanner(
            text: "Selama sesi latihan, audiens akan ikut merespon pada presentasimu.",
            isOvertime: false
        )
        enqueueBanner(
            text: "Jadi, lakukan presentasi dengan baik. Jangan sampai mereka bosan!",
            isOvertime: false
        )
    }

    private func enqueueBanner(text: String, isOvertime: Bool) {
        let item = BannerItem(text: text, isOvertime: isOvertime)
        bannerQueue.append(item)
        processQueueIfNeeded()
    }

    private func processQueueIfNeeded() {
        guard currentBanner == nil, !bannerQueue.isEmpty else { return }
        currentBanner = bannerQueue.removeFirst()
    }

    private func advanceBannerQueue() {
        currentBanner = nil
        processQueueIfNeeded()
    }

}

struct ComponentObjective: View {
    let text: String
    let isOvertime: Bool
    var onFinished: (() -> Void)? = nil   // dipanggil setelah animasi selesai

    @State private var appear = false

    private var fadeMask: some View {
        LinearGradient(
            gradient: Gradient(stops: [
                .init(color: .clear,  location: 0.0),
                .init(color: .white,  location: 0.30),
                .init(color: .white,  location: 0.70),
                .init(color: .clear,  location: 1.0)
            ]),
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    var body: some View {
        ZStack {
            // background gelap ikut animasi muncul/hilang
            Color.black
                .opacity(appear ? 0.5 : 0.0)
                .ignoresSafeArea()

            Text(text)
                .padding(.horizontal, 64)
                .padding(.vertical, 10)
                .foregroundColor(.white)
                .background(
                    (isOvertime ? Color.baseColorRed : Color.blue)
                        .mask(fadeMask)
                )
                .frame(maxWidth: .infinity)
                .offset(y: appear ? 0 : -20)
                .opacity(appear ? 1 : 0)
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: appear)
        .onAppear {
            // animasi masuk
            appear = true

            // tampil 3 detik
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                // animasi keluar
                withAnimation(.easeOut(duration: 0.25)) {
                    appear = false
                }

                // beri waktu animasi keluar
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    onFinished?()
                }
            }
        }
    }
}


struct BannerItem: Identifiable, Equatable {
    let id = UUID()
    let text: String
    let isOvertime: Bool
}
