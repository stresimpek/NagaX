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
    
    @StateObject private var viewModel: ModalViewModel
     
    init(onStart: @escaping () -> Void, settings: PracticeSettings) {
        self.onStart = onStart
        self._viewModel = StateObject(wrappedValue: ModalViewModel(practiceSettings: settings))
    }
     
    var body: some View {
        GeometryReader { geometry in
             
            ZStack {
                Color("BaseColorBlue")
                    .edgesIgnoringSafeArea(.all)
                   
                VStack(spacing: 0) {
                     
                    Spacer().frame(height: geometry.size.height * 0.1)

                    VStack(spacing: 0) {
                        Spacer().frame(height: geometry.size.height * 0.005)
                        
                        // **MODIFIKASI: Tampilkan judul yang berbeda untuk setup kamera**
                        if viewModel.currentStep == .cameraSetup {
                            Text("DETEKSI GERAKAN MATA")
                                .font(.title2.weight(.black))
                                .foregroundColor(.baseColorBrown)
                                .underline(true, color: .baseColorBrown)
                        } else {
                            TitleView()
                        }
                        
                        Spacer().frame(height: geometry.size.height * 0.01)
                        
                        VStack {
                            switch viewModel.currentStep {
                            
                            // **MODIFIKASI: Panggil "Dumb View" yang baru**
                            case .cameraSetup:
                                EyeContactMainView(viewModel: viewModel)
                                // View ini sudah punya tinggi sendiri (150)
                                
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
                                .frame(height: 150)
                                
                            case .distanceCheck:
                                Image(viewModel.mainImageName)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(height: 100)
                            }
                        }
                        .frame(minHeight: 150)
                        .animation(.easeInOut, value: viewModel.currentStep)
                        
//                        Spacer().frame(height: geometry.size.height * 0.01)
                        
                        // **MODIFIKASI: Tampilkan InstructionText, jangan disembunyikan**
                        InstructionTextView(
                            message: viewModel.instructionText,
                            geometry: geometry
                        )
                        // **MODIFIKASI: Ubah warna teks jika gagal**
                        .foregroundColor(
                            viewModel.currentStep == .cameraSetup && viewModel.cameraCheckState == .failed
                            ? .baseColorRed
                            : .baseColorBrown
                        )
                        .frame(height: 80, alignment: .center) // Pastikan tingginya konsisten
                        
//                        Spacer().frame(height: geometry.size.height * 0.1)
                    }
                    .padding(.horizontal, geometry.size.width * 0.06)
                    .frame(width: geometry.size.width * 0.85)
                    .background(
                        Image("SetupPaper")
                            .resizable()
                            .scaledToFill()
                    )
                    .zIndex(0)

                    // KODE BARU
                    VStack {
                        if viewModel.currentStep == .cameraSetup {
                            // --- Logika Tombol untuk .cameraSetup ---
                            if viewModel.cameraCheckState == .success {
                                ButtonComponent(
                                    title: "MULAI LATIHAN",
                                    systemImage: nil,
                                    size: .large,
                                    kind: .primaryYellow,
                                    action: onStart // <-- BENAR: Ini adalah akhir flow, panggil onStart
                                )
                            } else if viewModel.cameraCheckState == .failed {
                                ButtonComponent(
                                    title: "DETEKSI ULANG",
                                    systemImage: nil,
                                    size: .large,
                                    kind: .primaryYellow,
                                    action: viewModel.resetFlow // Panggil reset di VM
                                )
                            } else {
                                // Placeholder agar layout tidak "lompat"
                                Rectangle()
                                    .fill(Color.clear)
                                    .frame(height: 60)
                            }
                        } else {
                            // --- Logika Tombol untuk .micCheck, .quietRoom, .distanceCheck ---
                            StartButtonView(
                                title: viewModel.buttonTitle,
                                isEnabled: viewModel.isButtonEnabled,
                                action: {
                                    // LOGIKA BARU YANG LEBIH CERDAS:
                                    if viewModel.currentStep == .distanceCheck && !viewModel.needsCameraCheck {
                                        // Kasus 1: Di step 'Distance' DAN tidak perlu kamera
                                        onStart() // Ini adalah akhir flow
                                    } else {
                                        // Kasus 2: Semua step lain (.micCheck, .quietRoom,
                                        // atau .distanceCheck yang PERLU kamera)
                                        viewModel.nextStep() // Lanjut ke step berikutnya
                                    }
                                }
                            )
                        }
                    }
                    .frame(width: geometry.size.width * 0.3)
                    .offset(y: -geometry.size.height * 0.03)
                    .zIndex(1)
                       
                    Spacer().frame(height: geometry.size.height * 0)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onDisappear {
            viewModel.stopMonitoring()
            viewModel.stopAllTimers() // **TAMBAHKAN: Matikan timer kamera**
        }
        // **TAMBAHKAN: Event handler .onChange pindah ke sini**
        .onChange(of: viewModel.gazeOnTarget) { _, newValue in
            viewModel.handleGazeChange(isGazing: newValue)
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
