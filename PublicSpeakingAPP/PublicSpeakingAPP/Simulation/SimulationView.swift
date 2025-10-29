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
    let whisperKitVM: SpeechTranscriberViewModel
    let textAnalyzerVM: TextFrequencyAnalyzerViewModel
    let intonationAnalyzerVM: IntonationAnalyzerViewModel
    let tempoVM: TempoViewModel
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
                tempoVM: tempoVM
            ),
            onBack: onBack, // BARU: Teruskan closure
            onComplete: onComplete // BARU: Teruskan closure
        )
    }
}

struct SimulationView: View {
    
    @StateObject private var viewModel: SimulationViewModel
//    @Environment(\.dismiss) var dismiss
    
    let onBack: () -> Void
    let onComplete: (EvaluationModel, String) -> Void
    
    private var isProcessing: Bool {
            // Tampilkan "Menganalisis..." HANYA JIKA:
            // 1. Kita TIDAK sedang merekam
            // 2. DAN WhisperKit SEDANG melakukan transkripsi (ini adalah Fase 1)
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
                    
                VStack(spacing: -gridHeight * 0.15) {
                    HStack(spacing: 0) {
                        AnimatedActorView(targetFrames: viewModel.studentMoods[0].animationFrames, isAnimating: viewModel.isRecording)
                        AnimatedActorView(targetFrames: viewModel.studentMoods[1].animationFrames, isAnimating: viewModel.isRecording)
                        AnimatedActorView(targetFrames: viewModel.studentMoods[2].animationFrames, isAnimating: viewModel.isRecording)
                    }
                    .frame(height: gridHeight * 0.30)
                    
                    HStack(spacing: 0) {
                        AnimatedActorView(targetFrames: viewModel.studentMoods[3].animationFrames, isAnimating: viewModel.isRecording)
                        AnimatedActorView(targetFrames: viewModel.studentMoods[4].animationFrames, isAnimating: viewModel.isRecording).hidden()
                        AnimatedActorView(targetFrames: viewModel.studentMoods[5].animationFrames, isAnimating: viewModel.isRecording)
                    }
                    .frame(height: gridHeight * 0.35)
                    
                    HStack(spacing: 0) {
                        AnimatedActorView(targetFrames: viewModel.studentMoods[6].animationFrames, isAnimating: viewModel.isRecording)
                        AnimatedActorView(targetFrames: viewModel.studentMoods[7].animationFrames, isAnimating: viewModel.isRecording).hidden()
                        AnimatedActorView(targetFrames: viewModel.studentMoods[8].animationFrames, isAnimating: viewModel.isRecording)
                    }
                    .frame(height: gridHeight * 0.40)
                }
                .frame(height: gridHeight)
                .frame(width: geo.size.width * 0.9)
                .position(x: geo.size.width / 2, y: geo.size.height * 0.6)

                AnimatedActorView(targetFrames: viewModel.teacherMood.animationFrames, isAnimating: viewModel.isRecording)
                .frame(height: geo.size.height * 0.65)
                .position(x: geo.size.width / 2, y: geo.size.height * 0.7)
                
                VStack {
                    ZStack {
                        HStack {
                            Button(action: onBack) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 20, weight: .bold))
                                    .padding()
                                    .background(.black.opacity(0.1))
                                    .cornerRadius(10)
                                    .foregroundColor(.black)
                            }
                            Spacer()
                        }
                        
                        Text("Objective: Buat Mr. Beluga tersenyum!")
                            .font(.headline)
                            .padding()
                            .background(.black.opacity(0.1))
                            .cornerRadius(10)
                    }
                    .padding(.top, 20)
                    .padding(.horizontal)

//                    .overlay(alignment: .topTrailing) {
//                        VStack(spacing: 4) {
//                            Button("Teacher Happy") { viewModel.setTeacherMood(.happy) }
//                            Button("Teacher Angry") { viewModel.setTeacherMood(.angry) }
//                            Button("Students Focus") { viewModel.setStudentMoods(.focus) }
//                            Button("Students Sleep") { viewModel.setStudentMoods(.sleep) }
//                        }
//                        .padding(.top, 20)
//                        .padding(.trailing)
//                        .buttonStyle(.bordered)
//                        .tint(.gray)
//                        .font(.system(size: 10))
//                    }
                    
                    Spacer()
                    
                    HStack {
                        Text(viewModel.formattedTime)
                            .font(.system(size: 40, weight: .bold, design: .monospaced))
                            .foregroundColor(.black)
                            .padding(8)
                            .background(.black.opacity(0.1))
                            .cornerRadius(10)
                        
                        Spacer()
                        
                        HStack(spacing: 5) {
                            Button(action: viewModel.toggleRecording) {
                                Image(systemName: viewModel.isRecording ? "stop.circle.fill" : "record.circle")
                                    .font(.system(size: 40))
                                    .foregroundColor(viewModel.isRecording ? .red : .black)
                            }
                            .disabled(viewModel.whisperModelState != .loaded || isProcessing )
                            
                            VStack(alignment: .leading) {
                                Text(viewModel.isRecording ? "STOP\nRECORD" : "START\nRECORD")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.black)
                                    .lineLimit(2)
                                
                                if viewModel.whisperModelState != .loaded && !viewModel.isRecording {
                                    Text(viewModel.whisperModelState.description)
                                        .font(.caption2)
                                        .foregroundColor(.gray)
                                }
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 10)
                        .background(.black.opacity(0.1))
                        .cornerRadius(10)
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
                print("onReceive isAnalysisComplete: \(isComplete)") // Log 1
                if isComplete {
                    if let result = viewModel.evaluationResult {
                        print("Evaluation result FOUND. Calling onComplete...") // Log 2a
                        onComplete(result, viewModel.finalTranscript)
                    } else {
                        print("Evaluation result is NIL. Calling onBack...") // Log 2b
                        // Mungkin tampilkan error dulu?
                        // viewModel.errorMessage = "Gagal memproses hasil evaluasi."
                        onBack() // Kembali jika tidak ada hasil
                    }
                }
            }
            .navigationBarBackButtonHidden(true)
        }
    }
}
