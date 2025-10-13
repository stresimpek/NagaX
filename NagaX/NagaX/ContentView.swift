//
//  ContentView.swift
//  NagaX
//
//  Created by Jordan on 02/10/25.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = TranscriptionViewModel()
    @State private var isRecording = false
    
    var body: some View {
        VStack {
            ScrollView {
                if viewModel.isLoadingModel {
                    Text("⏳ Sedang memuat model...")
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding()
                } else if viewModel.isRecording {
                    Text("🎤 Sedang merekam...")
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding()
                } else if viewModel.isTranscribing {
                    Text("⚙️ Sedang transkripsi...")
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding()
                } else {
                    Text(viewModel.transcription)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                }
            }
            .padding()
            
            Button(isRecording ? "Stop & Transcribe" : "Start Recording") {
                if isRecording {
                    Task {
                        await viewModel.stopAndTranscribe()
                        isRecording = false
                    }
                } else {
                    viewModel.startRecording()
                    isRecording = true
                }
            }
            .buttonStyle(.borderedProminent)
            .padding()
        }.onAppear {
            Task {
                await viewModel.setupWhisper()
            }
        }

    }
}
