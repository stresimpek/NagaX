//
//  Homepage.swift
//  PublicSpeakingAPP
//
//  Created by Elisabeth Levana on 20/10/25.
//

import SwiftUI

enum Route: Hashable {
    case tips
    case settings
    case simulation(PracticeSettings)
    case evaluation(result: EvaluationModel, transcript: String, settings: PracticeSettings)
}

struct HomeView: View {
    @State private var path: [Route] = []

    @EnvironmentObject private var whisperKitVM: SpeechTranscriberViewModel
    @EnvironmentObject private var textAnalyzerVM: TextFrequencyAnalyzerViewModel
    @EnvironmentObject private var intonationAnalyzerVM: IntonationAnalyzerViewModel
    @EnvironmentObject private var tempoVM: TempoViewModel

    var body: some View {
        NavigationStack(path: $path) {
            // ROOT (Home)
            HomeContentView(
                onStart: { path.append(.tips) } // tombol "Mulai Presentasi"
            )
            .onAppear {
                // wiring tambahan kalau perlu
                whisperKitVM.textAnalyzerVM = textAnalyzerVM
                whisperKitVM.intonationAnalyzerVM = intonationAnalyzerVM
                whisperKitVM.tempoVM = tempoVM
                whisperKitVM.onAppear()
            }
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .tips:
                    TipsPresentasiView(
                        onBack: {                      // kembali ke Home
                            path.removeAll()
                        },
                        onContinue: {                  // ke Settings
                            path.append(.settings)
                        }
                    )
                    
                case .settings:
                    SettingsView(
                        onBack: {                      // balik ke Tips
                            path.removeLast()
                        },
                        onNext: { settings in
                            path.append(.simulation(settings))
                        }
                    )
                    
                case .simulation(let settings):
                    // Bisa pakai env objects (disarankan), jadi tak perlu param:
                    SimulationViewWrapper(
                        whisperKitVM: whisperKitVM,
                        textAnalyzerVM: textAnalyzerVM,
                        intonationAnalyzerVM: intonationAnalyzerVM,
                        tempoVM: tempoVM,
                        settings: settings,
                        onBack: {                      // balik ke Tips
                            path.removeLast()
                        },
                        onComplete: { result, transcript in
                            path.append(.evaluation(result: result, transcript: transcript, settings: settings))
                        }
                    )
                    .navigationBarBackButtonHidden(true)
                    
                case .evaluation(let result, let transcript, let settings):
                    EvaluationView(
                        result: result,
                        fullTranscript: transcript,
                        settings: settings, // <-- Teruskan 'settings'
                        onBack: {
                            // "Selesai" -> Kembali ke Home
                            path.removeAll()
                        },
                        onNext: { passedSettings in
                            guard path.count >= 2 else {
                                print("Error: Path tidak cukup panjang untuk removeLast(2)")
                                // Mungkin kembali ke home sebagai fallback?
                                path.removeAll()
                                return
                            }
                            
                            // 2. Hapus DUA elemen terakhir (.evaluation DAN .simulation sebelumnya)
                            path.removeLast(2)
                            
                            // 3. Tambahkan Simulation baru
                            path.append(.simulation(passedSettings))
                        }
                    )
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        
    }
}
