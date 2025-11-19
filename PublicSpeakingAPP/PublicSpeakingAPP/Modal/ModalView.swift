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

                    ZStack(alignment: .top) {
                        Image("SetupPaper")
                            .resizable()
                            .scaledToFill()
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                        
                        VStack(spacing: 0) {
                            VStack {
                                Spacer().frame(height: geometry.size.height * 0.05)
                                TitleView()
                            }
                            .background(Color.clear)
                            
                            Spacer().frame(height: geometry.size.height * 0.035)
                            
                            ScrollView(.vertical, showsIndicators: false) {
                                VStack(spacing: 0) {
                                    
                                    Spacer().frame(height: geometry.size.height * 0.02)
                                    
                                    VStack {
                                        switch viewModel.currentStep {
                                        case .quietRoom:
                                            Image(viewModel.mainImageName)
                                                .resizable()
                                                .scaledToFit()
                                                .frame(height: 100)
                                            
                                        case .micCheck:
                                            MicSetupView(
                                                micMonitor: viewModel.micMonitor,
                                                showMicWarning: viewModel.showMicWarning,
                                                imageName: viewModel.mainImageName
                                            )
                                            
                                        case .cameraPosition:
                                            Image(viewModel.mainImageName)
                                                .resizable()
                                                .scaledToFit()
                                                .frame(height: 100)
                                        }
                                    }
                                    .frame(height: 150)
                                    .animation(.easeInOut, value: viewModel.currentStep)
                                    
                                    Spacer().frame(height: geometry.size.height * 0.01)
                                    
                                    InstructionTextView(
                                        message: viewModel.instructionText,
                                        geometry: geometry
                                    )
                                    .padding(.bottom, 80)
                                }
                            }
                        }
                    }
                    .frame(width: geometry.size.width * 0.85)
                    .frame(maxHeight: geometry.size.height * 0.75)
                    .zIndex(0)

                    StartButtonView(
                        title: viewModel.buttonTitle,
                        isEnabled: viewModel.isButtonEnabled,
                        action: {
                            if viewModel.currentStep == .cameraPosition {
                                onStart()
                            } else {
                                viewModel.nextStep()
                            }
                        }
                    )
                    .frame(width: geometry.size.width * 0.3)
                    .offset(y: -geometry.size.height * 0.03)
                    .zIndex(1)
                       
                    Spacer().frame(height: 0)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
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
