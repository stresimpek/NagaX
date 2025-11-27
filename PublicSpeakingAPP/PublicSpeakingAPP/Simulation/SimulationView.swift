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
    
    @AppStorage("objectiveDontShowAgain") private var objectiveDontShowAgain = false
    
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    private var isAccessibilitySize: Bool { dynamicTypeSize.isAccessibilitySize }
    
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
    @State private var showPauseModal: Bool = false
    
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
                    
                    if viewModel.isRecording && !showPauseModal {
                        HStack {
                            ButtonComponent(
                                title: nil,
                                systemImage: "pause.fill",
                                size: .largeIconCircle,
                                kind: .primaryYellow,
                                action: {
                                                viewModel.pauseForModal()  // Use new function
                                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                                                    showPauseModal = true
                                                }
                                            }
                            )
                            .disabled(viewModel.whisperModelState != .loaded || isProcessing)
                            .padding(.top, 16)
                            .accessibilityLabel("Jeda")
                            
                            Spacer()
                        }
                    }
                    
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

                    HStack(alignment: .bottom) {
                        let alarmIconSize: CGFloat = isAccessibilitySize ? 18 : 22
                        let timerFont: Font = {
                           if viewModel.isOvertime {
                               return isAccessibilitySize ? .headline : .title
                           } else {
                               return isAccessibilitySize ? .headline : .title2
                           }
                        }()
                        if viewModel.isOvertime {
                            HStack(alignment: .center, spacing: 6) {
                                Image(systemName: "alarm.fill")
                                    .font(.system(size: alarmIconSize, weight: .semibold))
                                Text(viewModel.formattedTime)
                                    .font(timerFont)
                            }
                            .font(.title)
                            .padding(12)
                            .foregroundColor(.baseColorRed)
                            .background(.coral)
                            .cornerRadius(24)
                            .shadow(color: .lightCoral, radius: 0, x: 0, y: 4)
                            .accessibilityHidden(true)
                        } else {
                            HStack(alignment: .center, spacing: 6) {
                                Image(systemName: "alarm.fill")
                                    .font(.system(size: alarmIconSize, weight: .semibold))
                                Text(viewModel.formattedTime)
                                    .font(timerFont)
                            }
                            .font(.title2)
                            .padding(12)
                            .foregroundColor(.baseColorWhite)
                            .background(.darkBlue)
                            .cornerRadius(24)
                            .shadow(color: .darkBlue2, radius: 0, x: 0, y: 4)
                            .accessibilityHidden(true)
                        }
                        
                        Spacer()
                        
                        if viewModel.isRecording {
                            ZStack(alignment: .leading) {
                                AudioVisualizerModalView(micMonitor: micMonitor)
                                    .padding(.leading, 30)
                                    .padding(.trailing, 0)
                                    .frame(width: isAccessibilitySize ? 240 : 280, height: 50)
                                    .frame(alignment: .leading)
                                    .background(Color.black.opacity(0.27))
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                                    .offset(x: 20)
                                
                                MicIconButton(showMicWarning: false)
                            }
                            .accessibilityHidden(true)
                        }
                        
                        Spacer()
                        
                        HStack(spacing: 5) {
                            let recordTitle: String = {
                                if viewModel.isRecording {
                                    return isAccessibilitySize ? "Selesai\nRekam" : "Selesai Rekam"
                                } else {
                                    return isAccessibilitySize ? "Mulai\nRekam" : "Mulai Rekam"
                                }
                            }()
                            ButtonRecord(
                                title: recordTitle,
                                systemImage: viewModel.isRecording ? "stop.fill" : "circle.fill",
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
                    .padding(.bottom, 10)
                    .frame(maxWidth: .infinity)
                }
                .zIndex(10)

                if isProcessing && !showPauseModal {
                    Color.black.opacity(0.5)
                        .ignoresSafeArea()
                        .zIndex(11)
                    ProgressView("Menganalisis...")
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.5)
                        .font(.title3)
                        .foregroundColor(.white)
                        .zIndex(12)
                        .accessibilityHidden(true)
                }
            }
            .overlay(alignment: .top) {
                if let banner = currentBanner {
                    ComponentObjective(
                        text: banner.text,
                        isOvertime: banner.isOvertime,
                        onFinished: {
                            advanceBannerQueue()
                        },
                        dontShowAgain: $objectiveDontShowAgain,
                        showDontShowAgain: banner.showDontShowAgain
                    )
                    .id(banner.id)
                }
            }
            .onAppear {
                setupInitialBanners()
                isOverOneMinutes = false
                hasShownOvertimeBanner = false
            }
            .overlay {
                if viewModel.whisperKitVM.showEarlyStopModal && !showPauseModal && !viewModel.isManualPause {
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
                            
                if viewModel.whisperKitVM.showEmptyTranscriptModal && !showPauseModal && !viewModel.isManualPause{
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
                
                if showPauseModal {
                    BackModalView(
                        onBackHome: {
                            showPauseModal = false
                            viewModel.isManualPause = false
                            onBack()
                        },
                        onPause: {
                            showPauseModal = false
                            viewModel.resumeAfterEarlyStop()
                        },
                        onRetry: {
                            showPauseModal = false
                            viewModel.restartAfterEmptyTranscript()
                        }
                    )
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
                        isOvertime: true,
                        showDontShowAgain: false
                    )
                }
            }
            .navigationBarBackButtonHidden(true)
            .task {
                viewModel.whisperKitVM.resetState()
                viewModel.tempoVM.clearResults()
                viewModel.fillerWordVM.clearResults()
                viewModel.intonationAnalyzerVM.clearResults()
            }
            .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") { viewModel.errorMessage = nil }
            } message: {
                if let error = viewModel.errorMessage { Text(error) }
            }
        }
    }
}

extension SimulationView {
    private func setupInitialBanners() {
        guard objectiveDontShowAgain==false else { return }
        enqueueBanner(
            text: "Selama sesi latihan, audiens akan ikut merespon pada presentasimu.",
            isOvertime: false,
            showDontShowAgain: false
        )
        enqueueBanner(
            text: "Lakukan presentasi terbaikmu. Jangan sampai audiens bosan!",
            isOvertime: false,
            showDontShowAgain: true
        )
    }

    private func enqueueBanner(
        text: String,
        isOvertime: Bool,
        showDontShowAgain: Bool = false
    ) {
        let item = BannerItem(
            text: text,
            isOvertime: isOvertime,
            showDontShowAgain: showDontShowAgain
        )
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
