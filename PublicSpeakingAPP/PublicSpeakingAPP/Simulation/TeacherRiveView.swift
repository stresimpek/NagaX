//
//  R.swift
//  PublicSpeakingAPP
//
//  Created by Regina Celine Adiwinata on 06/11/25.
//

//
//  R.swift
//  PublicSpeakingAPP
//
//  Created by Regina Celine Adiwinata on 06/11/25.
//

import SwiftUI
import Combine
import UIKit

enum BelugaMood {
    case neutral, happy, angry
}

struct TeacherRiveView: View {
    @ObservedObject var sim: SimulationViewModel
    @StateObject private var ctrl: SimulationRiveController
    @State private var lastSent: Double = 0.0
    
    @State private var currentMood: BelugaMood = .neutral
    
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor

    init(sim: SimulationViewModel) {
        self._sim = ObservedObject(initialValue: sim)
        _ctrl = StateObject(wrappedValue: SimulationRiveController(settings: sim.settings))
    }

    var body: some View {
        ctrl.view()
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(moodDescription)
            .accessibilitySortPriority(sim.isRecording ? 1 : 3)
            .onAppear {
                Task { @MainActor in
                    ctrl.triggerBoredomBar(value: false)
                    ctrl.setScore(0.0)
                    lastSent = 0.0
                    currentMood = .neutral
                    
                    ctrl.triggerDifferentiateWithoutColor(value: differentiateWithoutColor)
                }
            }
            .onChange(of: differentiateWithoutColor) { newValue in
                ctrl.triggerDifferentiateWithoutColor(value: newValue)
            }
            .onReceive(sim.$presentationScore
                .map { ($0 * 100).rounded() / 100 }
                .removeDuplicates()
                .receive(on: RunLoop.main)
            ) { score in
                guard abs(score - lastSent) >= 0.01 else { return }
                
                let mood: BelugaMood
                if score > 0.5 {
                    mood = .happy
                } else if score < -0.5 {
                    mood = .angry
                } else {
                    mood = .neutral
                }
                
                currentMood = mood
                ctrl.setScore(score)
                lastSent = score
            }
            .onReceive(sim.$isRecording) { isRecording in
                if isRecording {
                    ctrl.resumeAll()
                    ctrl.startDistractionLoop()
                } else {
                    ctrl.pauseAll()
                }
            }
            .onReceive(sim.$isOverOneMinuteTrigger) { value in
                if value == true {
                    ctrl.triggerBoredomBar(value: true)
                }
            }
    }
}

private extension TeacherRiveView {
    
    var moodDescription: String {
        switch currentMood {
        case .happy:
            return "Audiens tertarik."
        case .angry:
            return "Audiens bosan."
        case .neutral:
            return "Audiens netral."
        }
    }
}
