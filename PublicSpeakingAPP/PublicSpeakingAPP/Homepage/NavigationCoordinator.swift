//
//  NavigationCoordinator.swift
//  PublicSpeakingAPP
//
//  Created by Feby Agatha Christie Kurniawan on 29/10/25.
//

import SwiftUI
import Combine

enum Route: Hashable {
    case tips
    case settings
    case simulation(PracticeSettings)
    case evaluation(result: EvaluationModel, transcript: String, settings: PracticeSettings)
    case newEvaluation(EvaluationModel, String, PracticeSettings)
}

@MainActor
class NavigationCoordinator: ObservableObject {
    
    @Published var path: [Route] = []
    
    func goToTips() {
        path.append(.tips)
    }
    
    func goToSettings() {
        path.append(.settings)
    }
    
    func goToSimulation(_ settings: PracticeSettings) {
        path.append(.simulation(settings))
    }
    
    func goToEvaluation(result: EvaluationModel, transcript: String, settings: PracticeSettings) {
        path.append(.evaluation(result: result, transcript: transcript, settings: settings))
    }
    
    func goToNewEvaluation(result: EvaluationModel, transcript: String, settings: PracticeSettings) {
        path.append(.newEvaluation(result, transcript, settings))
    }
    
    func goBack() {
        guard !path.isEmpty else { return }
        path.removeLast()
    }
    
    func returnToHome() {
        path.removeAll()
    }
    
    func retrySimulation(from settings: PracticeSettings) {
        guard path.count >= 2 else {
            print("Error: Path tidak cukup panjang untuk retry")
            returnToHome()
            return
        }
        
        path.removeLast(2)
        goToSimulation(settings)
    }
}
