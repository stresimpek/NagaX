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
                            if !path.isEmpty { path.removeLast() }
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
                        tempoVM: tempoVM
                    )
                        .navigationBarBackButtonHidden(true)
                }
            }
        }
        .onAppear {
            // wiring tambahan kalau perlu
            whisperKitVM.textAnalyzerVM = textAnalyzerVM
            whisperKitVM.intonationAnalyzerVM = intonationAnalyzerVM
            whisperKitVM.tempoVM = tempoVM
            whisperKitVM.onAppear()
        }
    }
}


//import SwiftUI
//
//enum Route: Hashable {
//    case home
//    case tips
//    case settings
//    case simulation
//}
//
//struct HomeView: View {
//    // ... properties yang sudah ada ...
//    @State private var path: [Route] = []
//
//    @EnvironmentObject private var whisperKitVM: SpeechTranscriberViewModel
//    @EnvironmentObject private var textAnalyzerVM: TextFrequencyAnalyzerViewModel
//    @EnvironmentObject private var intonationAnalyzerVM: IntonationAnalyzerViewModel
//    @EnvironmentObject private var tempoVM: TempoViewModel
//
//    var body: some View {
//        NavigationStack(path: $path) {
//            // ====== Konten lama HomeView kamu pindah ke komponen agar rapi ======
//            HomeContentView(
//                onStart: { path.append(.tips) } // tombol "Mulai Presentasi"
//            )
//            .navigationDestination(for: Route.self) { route in
//                switch route {
//                case .home:
//                    HomeContentView(
//                        onStart: { path.append(.tips) } 
//                    )
//                case .tips:
//                    TipsPresentasiView(
//                        onBack: { path.append(.home) },
//                        onContinue: { path.append(.settings) }  // dari Tips -> Settings
//                    )
//
//                case .settings:
//                    SettingsView(
//                        onBack: { path.append(.tips) },
//                        onNext: { path.append(.simulation) }     // dari Settings -> Simulation
//                    )
//
//                case .simulation:
//                    // Tidak perlu lagi kirim VM satu2, sudah ada di Environment
//                    SimulationViewWrapper(
//                        whisperKitVM: whisperKitVM,
//                        textAnalyzerVM: textAnalyzerVM,
//                        intonationAnalyzerVM: intonationAnalyzerVM,
//                        tempoVM: tempoVM
//                    )
//                        .navigationBarBackButtonHidden(true)
//                }
//            }
//        }
//        // Tetap boleh lakukan pengkabelan VM tambahan di onAppear
//        .onAppear {
//            whisperKitVM.textAnalyzerVM = textAnalyzerVM
//            whisperKitVM.intonationAnalyzerVM = intonationAnalyzerVM
//            whisperKitVM.tempoVM = tempoVM
//            whisperKitVM.onAppear()
//        }
//    }
//}
