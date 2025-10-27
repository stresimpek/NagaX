//
//  LoadingView.swift
//  PublicSpeakingAPP
//
//  Created by Jordan on 23/10/25.
//

import SwiftUI
import WhisperKit

struct LoadingView: View {
    @EnvironmentObject private var whisperKitVM: SpeechTranscriberViewModel
    @EnvironmentObject private var textAnalyzerVM: TextFrequencyAnalyzerViewModel
    @EnvironmentObject private var intonationAnalyzerVM: IntonationAnalyzerViewModel
    @EnvironmentObject private var tempoVM: TempoViewModel

    private var statusText: String {
        switch whisperKitVM.modelState {
        case .downloading:
            return String(format: "Downloading model... %.0f%%", whisperKitVM.loadingProgressValue * 100)
        case .prewarming, .loading:
            return "Preparing model..."
        case .downloaded:
            return "Download complete. Loading..."
        case .unloaded:
            return "Initializing..."
        default:
            return "Loading..."
        }
    }

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            VStack(spacing: 25) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.5)

                Text(statusText)
                    .foregroundColor(.white)
                    .font(.headline)
                    .padding(.top, 10)

                ProgressView(value: whisperKitVM.loadingProgressValue)
                    .progressViewStyle(LinearProgressViewStyle(tint: .white))
                    .frame(width: 250)
                    .padding(.horizontal)
            }
        }
        .onAppear {
            whisperKitVM.textAnalyzerVM = textAnalyzerVM
            whisperKitVM.intonationAnalyzerVM = intonationAnalyzerVM
            whisperKitVM.tempoVM = tempoVM
            whisperKitVM.onAppear()
        }
    }
}
