//
//  PublicSpeakingAPPApp.swift
//  PublicSpeakingAPP
//
//  Created by Regina Celine Adiwinata on 30/09/25.
//

import SwiftUI

@main
struct PublicSpeakingAPPApp: App {
    @StateObject private var whisperKitVM = SpeechTranscriberViewModel()
    @StateObject private var textAnalyzerVM = TextFrequencyAnalyzerViewModel()
    @StateObject private var intonationAnalyzerVM = IntonationAnalyzerViewModel()
    @StateObject private var tempoVM = TempoViewModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(whisperKitVM)
                .environmentObject(textAnalyzerVM)
                .environmentObject(intonationAnalyzerVM)
                .environmentObject(tempoVM)
        }
    }
}
