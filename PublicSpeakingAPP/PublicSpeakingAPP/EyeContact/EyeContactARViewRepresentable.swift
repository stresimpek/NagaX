//
//  EyeContactARViewRepresentable.swift
//  PublicSpeakingAPP
//
//  Created by Jordan on 13/11/25.
//

import UIKit
import SwiftUI

struct EyeContactARViewRepresentable: UIViewControllerRepresentable {
    
    @ObservedObject var viewModel: ModalViewModel

    func makeUIViewController(context: Context) -> EyeContactViewController {
        let vc = EyeContactViewController()
        context.coordinator.viewModel = self.viewModel
        vc.delegate = context.coordinator
        return vc
    }
    
    func updateUIViewController(_ uiViewController: EyeContactViewController, context: Context) {
        context.coordinator.viewModel = self.viewModel
        
        if self.viewModel.resetARKit {
            uiViewController.resetCalibration()
            DispatchQueue.main.async {
                self.viewModel.resetARKit = false
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject, EyeContactViewControllerDelegate {
        var viewModel: ModalViewModel?

        func didUpdateGaze(point: CGPoint, onTarget: Bool) {
            DispatchQueue.main.async {
                guard let vm = self.viewModel else { return }
                
                if !vm.hasReceivedFirstGazePoint {
                    vm.hasReceivedFirstGazePoint = true
                }
                vm.gazePoint = point
                
                guard vm.cameraCheckState == .detecting || vm.cameraCheckState == .holding else {
                    return
                }
                
                if vm.gazeOnTarget != onTarget {
                    vm.gazeOnTarget = onTarget
                }
            }
        }
    }
}
