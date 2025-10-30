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
    case simulation
}

struct HomeView: View {
    @State private var path: [Route] = []

    @EnvironmentObject private var whisperKitVM: SpeechTranscriberViewModel
    @EnvironmentObject private var textAnalyzerVM: TextFrequencyAnalyzerViewModel
    @EnvironmentObject private var intonationAnalyzerVM: IntonationAnalyzerViewModel
    @EnvironmentObject private var tempoVM: TempoViewModel
    @EnvironmentObject private var fillerWordVM: FillerWordViewModel

    var body: some View {
        NavigationStack(path: $path) {
            // ROOT (Home)
            HomeContentView(
                onStart: { path.append(.tips) } // tombol "Mulai Presentasi"
            )
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
                        onNext: {                      // ke Simulation
                            path.append(.simulation)
                        }
                    )

                case .simulation:
                    // Bisa pakai env objects (disarankan), jadi tak perlu param:
                    SimulationViewWrapper(
                        whisperKitVM: whisperKitVM,
                        textAnalyzerVM: textAnalyzerVM,
                        intonationAnalyzerVM: intonationAnalyzerVM,
                        tempoVM: tempoVM,
                        fillerWordVM: fillerWordVM
                    )
                    .navigationBarBackButtonHidden(true)
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            // wiring tambahan kalau perlu
            whisperKitVM.textAnalyzerVM = textAnalyzerVM
            whisperKitVM.intonationAnalyzerVM = intonationAnalyzerVM
            whisperKitVM.tempoVM = tempoVM
            whisperKitVM.fillerWordVM = fillerWordVM
            whisperKitVM.onAppear()
        }
    }
}
