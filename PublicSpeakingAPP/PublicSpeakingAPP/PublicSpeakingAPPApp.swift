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
    @StateObject private var intonationAnalyzerVM = IntonationAnalyzerViewModel()
    @StateObject private var tempoVM = TempoViewModel()
    @StateObject private var fillerWordVM = FillerWordViewModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .modelContainer(for: PresentationDateModel.self)
                .environment(\.timeZone, TimeZone(identifier: "Asia/Jakarta")!)
                .environmentObject(whisperKitVM)
                .environmentObject(intonationAnalyzerVM)
                .environmentObject(tempoVM)
                .environmentObject(fillerWordVM)
                .task {
                    whisperKitVM.intonationAnalyzerVM = intonationAnalyzerVM
                    whisperKitVM.tempoVM = tempoVM
                    whisperKitVM.fillerWordVM = fillerWordVM
                }
        }
    }
}
