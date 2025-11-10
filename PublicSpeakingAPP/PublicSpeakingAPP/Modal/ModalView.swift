//
//  ModalView.swift
//  PublicSpeakingAPP
//
//  Created by Jordan on 06/11/25.
//

import SwiftUI
import AVFoundation

struct ModalView: View {
     
    let onStart: () -> Void
    
    @StateObject private var viewModel = ModalViewModel()
     
    var body: some View {
        GeometryReader { geometry in
             
            ZStack {
                Color("BaseColorBlue")
                    .edgesIgnoringSafeArea(.all)
                   
                VStack(spacing: 0) {
                     
                    Spacer().frame(height: geometry.size.height * 0.1)

                    VStack(spacing: 0) {
                        Spacer().frame(height: geometry.size.height * 0.005)
                        
                        TitleView()
                        
                        Spacer().frame(height: geometry.size.height * 0.01)
                        
                        MicSetupView(
                            micMonitor: viewModel.micMonitor,
                            showMicWarning: viewModel.showMicWarning
                        )
                        
                        Spacer().frame(height: geometry.size.height * 0.01)
                        
                        InstructionTextView(
                            message: viewModel.instructionMessage,
                            geometry: geometry
                        )
                        
                        Spacer().frame(height: geometry.size.height * 0.1)
                    }
                    .padding(.horizontal, geometry.size.width * 0.06)
                    .frame(width: geometry.size.width * 0.85)
                    .background(
                        Image("SetupPaper")
                            .resizable()
                            .scaledToFill()
                    )
                    .zIndex(0)

                    StartButtonView(
                        isEnabled: viewModel.isButtonEnabled,
                        action: {
                            if viewModel.permissionStatus == .granted {
                                onStart()
                            } else {
                                viewModel.showPermissionAlert = true
                            }
                        }
                    )
                    .frame(width: geometry.size.width * 0.3)
                    .offset(y: -geometry.size.height * 0.03)
                    .zIndex(1)
                       
                    Spacer().frame(height: geometry.size.height * 0)

                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                   
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear {
            viewModel.checkAndRequestMicPermission()
        }
        .onDisappear {
            viewModel.stopMonitoring()
        }
        .alert("Izin Mikrofon Ditolak", isPresented: $viewModel.showPermissionAlert) {
            Button("Batal") {}
            Button("Buka Pengaturan") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
        } message: {
            Text("Aplikasi ini memerlukan izin mikrofon untuk berlatih. Aktifkan di Pengaturan.")
        }
        .navigationBarBackButtonHidden(true)
        .navigationBarHidden(true)
    }
}
