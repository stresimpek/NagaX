//
//  Homepage.swift
//  PublicSpeakingAPP
//
//  Created by Elisabeth Levana on 20/10/25.
//

import SwiftUI

struct HomeView: View {
    @StateObject private var coordinator = NavigationCoordinator()

    var body: some View {
        NavigationStack(path: $coordinator.path) {
            HomeContentView(
                onStart: { coordinator.goToSettings() },
                onDatePicker: { coordinator.goToDatePicker() }
            )
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .tips:
                    TipsPresentasiView(
                        onBack: {
                            coordinator.returnToHome()
                        },
                        onContinue: {
                            coordinator.goToSettings()
                        }
                    )
                    
                case .datePicker:
                    DatePickerView(
                        onBack: {
                            coordinator.returnToHome()
                        }
                    )
                    .navigationBarBackButtonHidden(true)
                    
                case .settings:
                    SettingsView(
                        onBack: {
                            coordinator.goBack()
                        },
                        onNext: { settings in
                            coordinator.goToSimulation(settings)
                        }
                    )
                    
                case .simulation(let settings):
                    SimulationViewWrapper(
                        settings: settings,
                        onBack: {
                            coordinator.goBack()
                        },
                        onComplete: { result, transcript in
                            coordinator.goToNewEvaluation(result: result, transcript: transcript, settings: settings)
                        }
                    )
                    .navigationBarBackButtonHidden(true)
                    
                case .evaluation(let result, let transcript, let settings):
                    EvaluationView(
                        result: result,
                        fullTranscript: transcript,
                        settings: settings,
                        onBack: {
                            coordinator.returnToHome()
                        },
                        onNext: { passedSettings in
                            coordinator.retrySimulation(from: passedSettings)
                        }
                    )
                    .navigationBarBackButtonHidden(true)
                    
                case .newEvaluation(let result, let transcript, let settings):
                    NewEvaluationView(
                        result: result,
                        fullTranscript: transcript,
                        settings: settings,
                        onBack: {
                            coordinator.returnToHome()
                        },
                        onNext: { passedSettings in
                            coordinator.retrySimulation(from: passedSettings)
                        }
                    )
                    .navigationBarBackButtonHidden(true)
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .environmentObject(coordinator)
    }
}
