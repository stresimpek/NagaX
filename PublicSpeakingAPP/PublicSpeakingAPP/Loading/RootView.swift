//
//  RootView.swift
//  PublicSpeakingAPP
//
//  Created by Jordan on 23/10/25.
//

import SwiftUI
import WhisperKit

struct RootView: View {
    @EnvironmentObject private var whisperKitVM: SpeechTranscriberViewModel

    var body: some View {
        if whisperKitVM.modelState == .loaded {
            NavigationStack {
                HomeView()
            }
        } else {
            LoadingView()
        }
    }
}
