//
//  R.swift
//  PublicSpeakingAPP
//
//  Created by Regina Celine Adiwinata on 06/11/25.
//
//

import RiveRuntime
import SwiftUI
import Combine

// Controller yang menjaga instance Rive tetap hidup & semua call di MainActor
final class TeacherRiveController: ObservableObject {
    let rive = RiveViewModel(
        fileName: "prof_belagu",
        stateMachineName: "SMProf_Belagu",
        autoPlay: true,
        artboardName: "Prof_Belagu"
    )

    @MainActor
    func setScore(_ value: Double) {
        // debug: pastikan di main
        assert(Thread.isMainThread)
        rive.setInput("PresentationScore", value: Float(value))
    }

    func view() -> some View { rive.view() }
}

struct TeacherRiveView: View {
    @ObservedObject var sim: SimulationViewModel
    @StateObject private var ctrl = TeacherRiveController()
    @State private var lastSent: Double = .infinity

    var body: some View {
        ctrl.view()
            .onAppear {
                Task { @MainActor in
                    ctrl.setScore(0.0)          // initial
                    lastSent = 0.0
                }
            }
            // Pastikan receive di main, lalu kirim
            .onReceive(sim.$presentationScore
                .map { ($0 * 100).rounded() / 100 }
                .removeDuplicates()
                .receive(on: RunLoop.main)          // <-- penting
            ) { score in
                guard abs(score - lastSent) >= 0.01 else { return }
                ctrl.setScore(score)
                print("send to rive \(score)")
                lastSent = score
            }
    }
}
