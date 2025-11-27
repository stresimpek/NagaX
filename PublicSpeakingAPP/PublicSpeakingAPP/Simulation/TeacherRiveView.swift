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
    @State private var lastAnnouncedMood: BelugaMood? = nil

    init(sim: SimulationViewModel) {
        self._sim = ObservedObject(initialValue: sim)
        _ctrl = StateObject(wrappedValue: SimulationRiveController(settings: sim.settings))
    }

    var body: some View {
        ctrl.view()
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Prof. Belagu")
            .accessibilityValue(moodDescription)
            .onAppear {
                Task { @MainActor in
                    ctrl.triggerBoredomBar(value: false)
                    ctrl.setScore(0.0)
                    lastSent = 0.0
                }
            }
            .onReceive(sim.$presentationScore
                .map { ($0 * 100).rounded() / 100 }
                .removeDuplicates()
                .receive(on: RunLoop.main)
            ) { score in
                guard abs(score - lastSent) >= 0.01 else { return }
                let mood: BelugaMood
//                let riveScore: Double
                
                if score > 0.25 {
                    mood = .happy
//                    riveScore = 0.6
                } else if score < -0.35 {
                    mood = .angry
//                    riveScore = -0.6
                } else {
                    mood = .neutral
//                    riveScore = 0.0
                }
                
                currentMood = mood
                ctrl.setScore(score)
                lastSent = score
                
                announceMoodIfNeeded(mood)
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
            return "Prof. Belagu terlihat senang dengan performamu."
        case .angry:
            return "Prof. Belagu tampak kecewa dengan presentasimu."
        case .neutral:
            return "Prof. Belagu tampak netral."
        }
    }
    
    func announceMoodIfNeeded(_ mood: BelugaMood) {
        guard UIAccessibility.isVoiceOverRunning else { return }
        guard lastAnnouncedMood != mood else { return }
        guard mood != .neutral else {
            lastAnnouncedMood = mood
            return
        }
        
        let message: String
        switch mood {
        case .happy:
            message = "Beluga terlihat senang dengan performamu."
        case .angry:
            message = "Beluga tampak kecewa dengan presentasimu."
        case .neutral:
            message = "Beluga terlihat netral."
        }
        
        let attributed = NSMutableAttributedString(string: message)
        attributed.addAttribute(
            .accessibilitySpeechLanguage,
            value: "id-ID",
            range: NSRange(location: 0, length: attributed.length)
        )
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            UIAccessibility.post(
                notification: .announcement,
                argument: attributed
            )
            lastAnnouncedMood = mood
        }
    }
}
