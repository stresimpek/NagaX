//
//  SimulationARTrackerView.swift
//  PublicSpeakingAPP
//
//  Created by Jordan on 14/11/25.
//

import SwiftUI
import ARKit

struct SimulationARTrackerView: UIViewControllerRepresentable {
    
    @ObservedObject var viewModel: SimulationViewModel

    func makeUIViewController(context: Context) -> SimulationARTrackerVC {
        let vc = SimulationARTrackerVC()
        vc.delegate = context.coordinator
        return vc
    }
    
    func updateUIViewController(_ uiViewController: SimulationARTrackerVC, context: Context) {

    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, SimulationARTrackerDelegate {
        var parent: SimulationARTrackerView

        init(_ parent: SimulationARTrackerView) {
            self.parent = parent
        }
        
        func didUpdate(event: HeadGazeEvent) {
            Task { @MainActor in
                self.parent.viewModel.updateHeadGazeEvent(event)
            }
        }
    }
}
