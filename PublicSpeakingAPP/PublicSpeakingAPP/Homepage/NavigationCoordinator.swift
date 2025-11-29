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
    case datePicker
    case settings
    case simulation(PracticeSettings)
    case evaluationSummary(EvaluationModel, String, String, PracticeSettings)
    case newEvaluation(EvaluationModel, String, String, PracticeSettings)
    case modal(PracticeSettings, Bool)
    case notificationPrompt(Date)
}

@MainActor
class NavigationCoordinator: ObservableObject {
    
    @Published var path: [Route] = []
    
    func goToTips() {
        path.append(.tips)
    }
    
    func goToDatePicker() {
        path.append(.datePicker)
    }
    
    func goToSettings() {
        path.append(.settings)
    }
    
    func goToModal(settings: PracticeSettings, startAtCameraStep: Bool) {
        path.append(Route.modal(settings, startAtCameraStep))
    }
    
    func goToSimulation(_ settings: PracticeSettings) {
        path.append(.simulation(settings))
    }
    
    func goToEvaluationSummary(result: EvaluationModel, transcript: String, analysisResult: String, settings: PracticeSettings) {
        path.append(Route.evaluationSummary(result, transcript, analysisResult, settings))
    }
    
    func goToNewEvaluation(result: EvaluationModel, transcript: String, sentenceAnalysisResult: String, settings: PracticeSettings) {
        path.append(.newEvaluation(result, transcript, sentenceAnalysisResult, settings))
    }
    
    func goToNotificationPrompt(date: Date) {
        path.append(.notificationPrompt(date))
    }
    
    func goBack() {
        guard !path.isEmpty else { return }
        path.removeLast()
    }
    
    func returnToHome() {
        path.removeAll()
    }
    
    func retrySimulation(from settings: PracticeSettings) {
        if let lastSimulationIndex = path.lastIndex(where: {
            if case .simulation = $0 { return true }
            return false
        }) {
            path.removeSubrange(lastSimulationIndex...)
        }
        
        goToSimulation(settings)
    }
}
