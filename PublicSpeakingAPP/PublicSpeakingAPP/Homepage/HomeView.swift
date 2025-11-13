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
                        },
                        onComplete: { selectedDate in
                            coordinator.goToNotificationPrompt(date: selectedDate)
                        }
                    )
                    .navigationBarBackButtonHidden(true)
                    
                case .notificationPrompt(let date):
                    NotificationPromptView(
                        selectedDate: date,
                        onBack: {
                            coordinator.goBack()
                        },
                        onComplete: {
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
                            coordinator.goToModal(settings)
                        }
                    )
                
                case .modal(let settings):
                    ModalView(
                        onStart: {
                            coordinator.goToSimulation(settings)
                        }
                    )
                    
                case .simulation(let settings):
                    SimulationViewWrapper(
                        settings: settings,
                        onBack: {
                            coordinator.goBack()
                        },
                        onComplete: { result, transcript, analysisResult in
                            coordinator.goToNewEvaluation(
                                result: result,
                                transcript: transcript,
                                sentenceAnalysisResult: analysisResult,
                                settings: settings
                            )
                        }
                    )
                    .navigationBarBackButtonHidden(true)
                    
                case .newEvaluation(let result, let transcript, let sentenceAnalysisResult, let settings):
                    NewEvaluationView(
                        result: result,
                        fullTranscript: transcript,
                        sentenceAnalysisResult: sentenceAnalysisResult,
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
