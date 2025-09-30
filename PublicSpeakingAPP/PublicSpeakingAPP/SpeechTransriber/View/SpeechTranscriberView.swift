//
//  SpeechTranscriberView.swift
//  PublicSpeakingAPP
//
//  Created by Regina Celine Adiwinata on 30/09/25.
//

import SwiftUI
import UniformTypeIdentifiers

struct SpeechTranscriberView: View {
    @StateObject private var viewModel = SpeechTranscriberViewModel()

    @State private var presentImporter = false
    @State private var selectedURL: URL? = nil
    @State private var showingAlert: Bool = false

    var body: some View {
        VStack(spacing: 16) {
            // STATUS
            HStack(spacing: 8) {
                Circle()
                    .fill(viewModel.isRecording ? Color.green : Color.gray)
                    .frame(width: 10, height: 10)
                Text(viewModel.isRecording ? "Listening…" : "Idle")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)

            // LIVE CONTROLS
            HStack(spacing: 12) {
                Button {
                    viewModel.startLiveTranscription()
                } label: {
                    Label("Start Live Transcription", systemImage: "mic.fill")
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isRecording || !viewModel.canRecord)

                Button {
                    viewModel.stopLiveTranscription()
                } label: {
                    Label("Stop", systemImage: "stop.fill")
                }
                .buttonStyle(.bordered)
                .disabled(!viewModel.isRecording)
            }

            // ERROR
            if let error = viewModel.errorMessage {
                Text(error)
                    .foregroundStyle(.red)
                    .font(.footnote)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
            }

            // TRANSCRIPT
            ScrollView {
                Text(viewModel.transcript.isEmpty ? "Transcript will appear here..." : viewModel.transcript)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(8)
            .padding(.horizontal)
        }
        .padding()
        .onAppear {
            viewModel.requestAuthorization()
        }
    }
}

