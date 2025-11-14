//
//  SimulationARTrackerView.swift
//  PublicSpeakingAPP
//
//  Created by Jordan on 14/11/25.
//

import SwiftUI
import ARKit

struct SimulationARTrackerView: UIViewControllerRepresentable {
    
    // Terima ViewModel dari SimulationView
    @ObservedObject var viewModel: SimulationViewModel

    func makeUIViewController(context: Context) -> SimulationARTrackerVC {
        let vc = SimulationARTrackerVC()
        vc.delegate = context.coordinator // Set delegate-nya ke Coordinator
        return vc
    }
    
    func updateUIViewController(_ uiViewController: SimulationARTrackerVC, context: Context) {
        // Kita bisa kirim sinyal reset jika perlu
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    // Coordinator adalah class yang menjadi delegate
    // KODE BARU (FIX)
    class Coordinator: NSObject, SimulationARTrackerDelegate {
        var parent: SimulationARTrackerView

        init(_ parent: SimulationARTrackerView) {
            self.parent = parent
        }
        
        func didUpdate(event: HeadGazeEvent) {
            // Bungkus panggilan dalam Task @MainActor
            // untuk beralih ke thread utama dengan aman.
            Task { @MainActor in
                self.parent.viewModel.updateHeadGazeEvent(event)
            }
        }
    }
}
