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
    let onComplete: (EvaluationModel, String) -> Void
    
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
            onComplete: onComplete
        )
    }
}

struct SimulationView: View {
    
    @StateObject private var viewModel: SimulationViewModel
    @StateObject private var micMonitor = MicMonitor()
    
    let onBack: () -> Void
    let onComplete: (EvaluationModel, String) -> Void
    
    private var isProcessing: Bool {
        return !viewModel.isRecording && viewModel.whisperKitVM.isTranscribing
    }
    
    init(
        viewModel: SimulationViewModel,
        onBack: @escaping () -> Void,
        onComplete: @escaping (EvaluationModel, String) -> Void
    ) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.onBack = onBack
        self.onComplete = onComplete
    }
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                // === LAYER 0: Rive full screen ===
                TeacherRiveView(sim: viewModel)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .ignoresSafeArea()                 // <-- penuh, di bawah notch/home bar
                    .allowsHitTesting(false)           // biar tap ke UI atasnya tidak tertangkap Rive
                    .onChange(of: viewModel.isRecording) { _, newValue in
                        newValue ? micMonitor.startMonitoring() : micMonitor.stopMonitoring()
                    }

                // === LAYER 1+: Overlay UI ===
                VStack {
                    ZStack {
                        Group {
                            if viewModel.isOvertime {
                                Text(viewModel.isMoreThanOneMinute ? "LEWAT DURASI!" : "WAKTU HABIS!")
                                    .padding()
                                    .foregroundColor(.baseColorRed)
                                    .frame(height: 42)
                                    .background(.coral)
                                    .cornerRadius(24)
                                    .shadow(color: .lightCoral, radius: 0, x: 0, y: 4)
                            } else {
                                Text("Objective: Lakukan presentasi terbaikmu dengan aspek yang sudah ditentukan!")
                                    .padding()
                                    .foregroundColor(.baseColorBrown)
                                    .frame(height: 42)
                                    .background(.baseColorWhite)
                                    .cornerRadius(24)
                                    .shadow(color: .beige, radius: 0, x: 0, y: 4)
                            }
                        }
                        .font(.headline)
                        .animation(.easeInOut, value: viewModel.isOvertime)
                        .animation(.easeInOut, value: viewModel.isMoreThanOneMinute)
                        .padding(.top, 16)
                    }
                    .padding(.top, 20)
                    .padding(.horizontal)

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
                            AudioVisualizerView(micMonitor: micMonitor)
                                .padding(.top, 8)
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
                                    Text(viewModel.whisperModelState.description) .font(.caption2) .foregroundColor(.gray) }
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, geo.safeAreaInsets.bottom) // UI tetap hormati safe area bawah
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
            .onDisappear { viewModel.cleanup() }
            .onReceive(viewModel.$isAnalysisComplete) { isComplete in
                if isComplete {
                    if let result = viewModel.evaluationResult {
                        onComplete(result, viewModel.finalTranscript)
                    } else {
                        onBack()
                    }
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

}

