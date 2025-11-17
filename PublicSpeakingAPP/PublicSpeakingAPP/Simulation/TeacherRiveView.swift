//
//  R.swift
//  PublicSpeakingAPP
//
//  Created by Regina Celine Adiwinata on 06/11/25.
//

import SwiftUI
import Combine

struct TeacherRiveView: View {
    @ObservedObject var sim: SimulationViewModel
    @StateObject private var ctrl: SimulationRiveController
    @State private var lastSent: Double = 0.0

    init(sim: SimulationViewModel) {
        self._sim = ObservedObject(initialValue: sim)
        _ctrl = StateObject(wrappedValue: SimulationRiveController(settings: sim.settings))
    }

    var body: some View {
        ctrl.view()
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

