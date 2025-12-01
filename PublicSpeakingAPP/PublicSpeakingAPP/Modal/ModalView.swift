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
    @Environment(\.horizontalSizeClass) var sizeClass
    private var isiPad: Bool {
        sizeClass == .regular && UIDevice.current.userInterfaceIdiom == .pad
    }
    
    @StateObject private var viewModel: ModalViewModel
    
    @AccessibilityFocusState private var isTitleFocused: Bool
     
    init(onStart: @escaping () -> Void, settings: PracticeSettings, startAtCameraStep: Bool = false) {
        self.onStart = onStart
        self._viewModel = StateObject(
            wrappedValue: ModalViewModel(
                practiceSettings: settings,
                startAtCameraStep: startAtCameraStep
            )
        )
    }
     
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
                            .accessibilityHidden(true)
                        
                        VStack(spacing: 0) {
                            VStack {
                                Spacer().frame(height: geometry.size.height * 0.05)
                                TitleView()
                                    .accessibilityFocused($isTitleFocused)
                            }
                            .background(Color.clear)
                            .accessibilitySortPriority(3)
                            
                            if isiPad {
                                GeometryReader { geometry in
                                    ScrollView(.vertical, showsIndicators: false) {                                        VStack(spacing: 0) {
                                            Spacer()
                                            
                                            VStack {
                                                switch viewModel.currentStep {
                                                case .quietRoom:
                                                    MicroAnimation(artboardName: "Kondusif")
                                                        .frame(height: 100)
                                                    
                                                case .micCheck:
                                                    MicSetupView(
                                                        micMonitor: viewModel.micMonitor,
                                                        showMicWarning: viewModel.showMicWarning,
                                                        imageName: viewModel.mainImageName
                                                    )
                                                    
                                                case .distanceCheck:
                                                    MicroAnimation(artboardName: "ArmLength")
                                                        .frame(height: 100)
                                                case .volumeCheck:
                                                    MicroAnimation(artboardName: "VOLUME")
                                                        .frame(height: 100)
                                                case .cameraSetup:
                                                    EyeContactMainView(viewModel: viewModel)
                                                }
                                            }
                                            .frame(height: 160)
                                            .animation(.easeInOut, value: viewModel.currentStep)
                                            
                                            InstructionTextView(
                                                message: viewModel.instructionText,
                                                geometry: geometry
                                            )
                                            .padding(.bottom, 80)
                                            Spacer()
                                        }
                                        .frame(minHeight: geometry.size.height)
                                        .frame(maxWidth: .infinity)
                                    }
                                    .accessibilitySortPriority(2)
                                }
                            } else {
                                Spacer().frame(height: geometry.size.height * 0.035)
                                
                                ScrollView(.vertical, showsIndicators: false) {
                                    VStack(spacing: 0) {
                                        
                                        Spacer().frame(height: geometry.size.height * 0.02)
                                        
                                        VStack {
                                            switch viewModel.currentStep {
                                            case .quietRoom:
                                                MicroAnimation(artboardName: "Kondusif")
                                                    .frame(height: 100)
                                                
                                            case .micCheck:
                                                MicSetupView(
                                                    micMonitor: viewModel.micMonitor,
                                                    showMicWarning: viewModel.showMicWarning,
                                                    imageName: viewModel.mainImageName
                                                )
                                                
                                            case .distanceCheck:
                                                MicroAnimation(artboardName: "ArmLength")
                                                    .frame(height: 100)
                                            case .volumeCheck:
                                                MicroAnimation(artboardName: "VOLUME")
                                                    .frame(height: 100)
                                            case .cameraSetup:
                                                EyeContactMainView(viewModel: viewModel)
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
                                .accessibilitySortPriority(2)
                            }
                        }
                    }
                    .frame(width: geometry.size.width * 0.85)
                    .frame(maxHeight: geometry.size.height * 0.75)
                    .zIndex(0)

                    bottomButtonView(geometry: geometry)
                        .zIndex(1)
                        
                    Spacer().frame(height: 0)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onDisappear {
            viewModel.stopMonitoring()
            viewModel.stopAllTimers()
        }
        .onChange(of: viewModel.gazeOnTarget) { _, newValue in
            viewModel.handleGazeChange(isGazing: newValue)
        }
        .onChange(of: viewModel.currentStep) { _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isTitleFocused = true
                UIAccessibility.post(notification: .screenChanged, argument: nil)
            }
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

extension ModalView {
    
    @ViewBuilder
    private func paperContentView(geometry: GeometryProxy) -> some View {
        ZStack(alignment: .top) {
            Image("SetupPaper")
                .resizable()
                .scaledToFill()
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .accessibilityHidden(true)
           
            VStack(spacing: 0) {
                VStack {
                    Spacer().frame(height: geometry.size.height * 0.05)
                    headerTitleView
                        .accessibilityFocused($isTitleFocused)
                }
                .background(Color.clear)
                .accessibilitySortPriority(3)
               
                Spacer().frame(height: geometry.size.height * 0.035)
               
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 0) {
                        Spacer().frame(height: geometry.size.height * 0.02)
                       
                        mainStepContent
                            .frame(minHeight: 150)
                            .animation(.easeInOut, value: viewModel.currentStep)
                       
                        Spacer().frame(height: geometry.size.height * 0.01)
                       
                        instructionText(geometry: geometry)
                            .padding(.bottom, 80)
                    }
                }
                .accessibilitySortPriority(2)
            }
        }
        .frame(width: geometry.size.width * 0.85)
        .frame(maxHeight: geometry.size.height * 0.75)
    }
    
    @ViewBuilder
    private var headerTitleView: some View {
        if viewModel.currentStep == .cameraSetup {
            Text("DETEKSI GERAKAN MATA")
                .font(.title2.weight(.black))
                .foregroundColor(.baseColorBrown)
                .underline(true, color: .baseColorBrown)
        } else {
            TitleView()
        }
    }

    @ViewBuilder
    private var mainStepContent: some View {
        switch viewModel.currentStep {
          
        case .micCheck:
            MicSetupView(
                micMonitor: viewModel.micMonitor,
                showMicWarning: viewModel.showMicWarning,
                imageName: viewModel.mainImageName
            )
          
        case .quietRoom:
            MicroAnimation(artboardName: "Kondusif")
                .frame(height: 100)
                
        case .distanceCheck:
            MicroAnimation(artboardName: "ArmLength")
                .frame(height: 100)
          
        case .cameraSetup:
            EyeContactMainView(viewModel: viewModel)
        case .volumeCheck:
            MicroAnimation(artboardName: "VOLUME")
                .frame(height: 100)
        }
    }
    
    @ViewBuilder
    private func instructionText(geometry: GeometryProxy) -> some View {
        InstructionTextView(
            message: viewModel.instructionText,
            geometry: geometry
        )
        .foregroundColor(
            (viewModel.currentStep == .cameraSetup && viewModel.cameraCheckState == .failed)
            ? .baseColorRed
            : .baseColorBrown
        )
    }
    
    @ViewBuilder
    private func bottomButtonView(geometry: GeometryProxy) -> some View {
        VStack {
            if viewModel.currentStep == .cameraSetup {
                if viewModel.cameraCheckState == .success {
                    ButtonComponent(
                        title: "MULAI LATIHAN",
                        systemImage: nil,
                        size: .large,
                        kind: .primaryYellow,
                        action: onStart
                    )
                } else if viewModel.cameraCheckState == .failed {
                    ButtonComponent(
                        title: "DETEKSI ULANG",
                        systemImage: nil,
                        size: .large,
                        kind: .primaryYellow,
                        action: viewModel.resetFlow
                    )
                } else {
                    Rectangle()
                        .fill(Color.clear)
                        .frame(height: 60)
                }
               
            } else {
                StartButtonView(
                    title: viewModel.buttonTitle,
                    isEnabled: viewModel.isButtonEnabled,
                    action: {
                        if viewModel.currentStep == .distanceCheck && !viewModel.needsCameraCheck {
                            onStart()
                        } else {
                            viewModel.nextStep()
                        }
                    }
                )
            }
        }
        .frame(width: geometry.size.width * 0.3)
        .offset(y: -geometry.size.height * 0.03)
        .accessibilitySortPriority(1)
    }
}
