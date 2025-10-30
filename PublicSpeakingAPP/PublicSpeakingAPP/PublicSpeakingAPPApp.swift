//
//  PublicSpeakingAPPApp.swift
//  PublicSpeakingAPP
//
//  Created by Regina Celine Adiwinata on 30/09/25.
//

import SwiftUI
import SwiftData

@main
struct PublicSpeakingAPPApp: App {
    
    @StateObject private var whisperKitVM = SpeechTranscriberViewModel()
    @StateObject private var textAnalyzerVM = TextFrequencyAnalyzerViewModel()
    @StateObject private var intonationAnalyzerVM = IntonationAnalyzerViewModel()
    @StateObject private var tempoVM = TempoViewModel()
    @StateObject private var fillerWordVM = FillerWordViewModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(whisperKitVM)
                .environmentObject(textAnalyzerVM)
                .environmentObject(intonationAnalyzerVM)
                .environmentObject(tempoVM)
                .environmentObject(fillerWordVM)

//            NavigationStack {
//                HomeView()
//                    .environmentObject(whisperKitVM)
//                    .environmentObject(textAnalyzerVM)
//                    .environmentObject(intonationAnalyzerVM)
//                    .environmentObject(tempoVM)
//            }
        }
    }
}
