//
//  EyeContactMainView.swift
//  PublicSpeakingAPP
//
//  Created by Jordan on 13/11/25.
//

import SwiftUI

struct EyeContactMainView: View {
    
    @ObservedObject var viewModel: ModalViewModel

    var body: some View {
        
        ZStack {
            EyeContactARViewRepresentable(viewModel: viewModel)

            Circle()
                .fill(viewModel.gazeOnTarget ? Color("Turqoise") : Color("BaseColorRed"))
                .frame(width: 30, height: 30)
                .opacity(0.8)
                .animation(.easeInOut, value: viewModel.gazeOnTarget)
            
            Circle()
                .fill(viewModel.gazeOnTarget ? Color("Turqoise").opacity(0.7) : Color.clear)
                .overlay(Circle().stroke(Color.white, lineWidth: 2))
                .frame(width: 30, height: 30)
                .position(viewModel.gazePoint)
                .animation(.linear(duration: 0.1), value: viewModel.gazePoint)
                .animation(.easeInOut, value: viewModel.gazeOnTarget)
                .opacity(viewModel.hasReceivedFirstGazePoint ? 1.0 : 0.0)

            Text(viewModel.cameraCheckState == .preparing || viewModel.cameraCheckState == .holding ? "\(viewModel.eyeContactCountdown)" : "")
                .font(.system(size: 48, weight: .bold))
                .foregroundColor(Color.white.opacity(0.85))
                .shadow(color: .black.opacity(0.5), radius: 5, x: 0, y: 2)
                .padding(.top, 50)
                .animation(nil, value: viewModel.eyeContactCountdown)
                .transition(.opacity.animation(.easeIn(duration: 0.1)))
        }
        .frame(width: 300, height: 150)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        
    }
}
