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
                let gridHeight = geo.size.height
                
                Image(.backgroundRuangKelas)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .edgesIgnoringSafeArea(.all)
                
                //                VStack(spacing: -gridHeight * 0.15) {
                //                    HStack(spacing: 0) {
                //                        AnimatedActorView(targetFrames: viewModel.studentMoods[0].animationFrames, isAnimating: viewModel.isRecording)
                //                        AnimatedActorView(targetFrames: viewModel.studentMoods[1].animationFrames, isAnimating: viewModel.isRecording)
                //                        AnimatedActorView(targetFrames: viewModel.studentMoods[2].animationFrames, isAnimating: viewModel.isRecording)
                //                    }
                //                    .frame(height: gridHeight * 0.30)
                //
                //                    HStack(spacing: 0) {
                //                        AnimatedActorView(targetFrames: viewModel.studentMoods[3].animationFrames, isAnimating: viewModel.isRecording)
                //                        AnimatedActorView(targetFrames: viewModel.studentMoods[4].animationFrames, isAnimating: viewModel.isRecording).hidden()
                //                        AnimatedActorView(targetFrames: viewModel.studentMoods[5].animationFrames, isAnimating: viewModel.isRecording)
                //                    }
                //                    .frame(height: gridHeight * 0.35)
                //
                //                    HStack(spacing: 0) {
                //                        AnimatedActorView(targetFrames: viewModel.studentMoods[6].animationFrames, isAnimating: viewModel.isRecording)
                //                        AnimatedActorView(targetFrames: viewModel.studentMoods[7].animationFrames, isAnimating: viewModel.isRecording).hidden()
                //                        AnimatedActorView(targetFrames: viewModel.studentMoods[8].animationFrames, isAnimating: viewModel.isRecording)
                //                    }
                //                    .frame(height: gridHeight * 0.40)
                //                    if viewModel.isRecording {
                //                                                AudioVisualizerView(micMonitor: micMonitor)
                //                                                    .padding(.top, 8)
                //                                            }
                //                }
                //                .frame(height: gridHeight)
                //                .frame(width: geo.size.width * 0.9)
                //                .position(x: geo.size.width / 2, y: geo.size.height * 0.6)
                //                .onChange(of: viewModel.isRecording) { isRecording in
                //                    if isRecording {
                //                        micMonitor.startMonitoring()
                //                    } else {
                //                        micMonitor.stopMonitoring()
                //                    }
                //                }
                AnimatedActorView(targetFrames: viewModel.teacherMood.animationFrames, isAnimating: viewModel.isRecording)
                    .frame(height: geo.size.height * 0.65)
                    .position(x: geo.size.width / 2, y: geo.size.height * 0.7)
                    .onChange(of: viewModel.isRecording) { oldValue, newValue in
                                        if newValue {
                                            micMonitor.startMonitoring()
                                        } else {
                                            micMonitor.stopMonitoring()
                                        }
                                    }
                
                
                VStack {
                    ZStack {
                        Group {
                            if viewModel.isOvertime {
                                Text(viewModel.isMoreThanOneMinute ? "LEWAT DURASI!" : "WAKTU HABIS!")
                                    .padding()
                                    .foregroundColor(.baseColorRed)
                                    .frame(height: 42, alignment: .center)
                                    .background(.coral)
                                    .cornerRadius(24)
                                    .shadow(color: .lightCoral, radius: 0, x: 0, y: 4)
                            } else {
                                Text("Objective: Lakukan presentasi terbaikmu dengan aspek yang sudah ditentukan!")
                                    .padding()
                                    .foregroundColor(.baseColorBrown)
                                    .frame(height: 42, alignment: .center)
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
                                    Text(viewModel.whisperModelState.description)
                                        .font(.caption2)
                                        .foregroundColor(.gray)
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, geo.safeAreaInsets.bottom)
                }
                .zIndex(10)
                
                if isProcessing {
                    Color.black.opacity(0.5)
                        .edgesIgnoringSafeArea(.all)
                        .zIndex(11)
                    
                    ProgressView("Menganalisis...")
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.5)
                        .font(.title3)
                        .foregroundColor(.white)
                        .zIndex(12)
                }
                
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .onDisappear {
                viewModel.cleanup()
            }
            .onReceive(viewModel.$isAnalysisComplete) { isComplete in
                print("onReceive isAnalysisComplete: \(isComplete)")
                if isComplete {
                    if let result = viewModel.evaluationResult {
                        print("Evaluation result FOUND. Calling onComplete...")
                        onComplete(result, viewModel.finalTranscript)
                    } else {
                        print("Evaluation result is NIL. Calling onBack...")
                        onBack()
                    }
                }
            }
            .navigationBarBackButtonHidden(true)
            .task {
                print("[SimulationView.task] Mereset state VM...")
                viewModel.whisperKitVM.resetState()
                viewModel.textAnalyzerVM.clearResults()
                viewModel.intonationAnalyzerVM.clearResults()
                viewModel.tempoVM.clearResults()
            }
            .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") { viewModel.errorMessage = nil }
            } message: {
                if let error = viewModel.errorMessage {
                    Text(error)
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .task {
            print("[SimulationView.task] Mereset state VM...")
            viewModel.whisperKitVM.resetState()
            viewModel.textAnalyzerVM.clearResults()
            viewModel.intonationAnalyzerVM.clearResults()
            viewModel.tempoVM.clearResults()
            viewModel.fillerWordVM.clearResults()
        }
    }
}
