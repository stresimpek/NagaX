//
//  SettingsView.swift
//  PublicSpeakingAPP
//
//  Created by Regina Celine Adiwinata on 22/10/25.
//

import SwiftUI
import AVFoundation

struct SettingsView: View {
    
    @State private var durationMinutes: Int = 1
    @State private var distractionLevel: Double = 0.0
    @State private var enableQnA: Bool = false
    @State private var randomTopic: Bool = false
    
    @State private var showAspectInfo: Bool = false
    @State private var showPermissionAlert: Bool = false
    // Menambahkan state untuk pesan alert yang dinamis
    @State private var alertMessage: String = ""
    
    let onBack: () -> Void
    let onNext: (PracticeSettings) -> Void

    private let aspectOptions: [AspectOption] = AspectOption.allOptions
    @State private var selectedAspects: Set<AspectOption> = []
    
    private var shouldDisableNext: Bool {
        selectedAspects.isEmpty || durationMinutes == 0
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            VStack(spacing: 0) {
                HStack(alignment: .center) {
                    RoomPreview()
                        .frame(maxWidth: 280)
                        .padding(.leading, 12)
                        .accessibilitySortPriority(2)

                    VStack(alignment: .leading, spacing: 18) {
                        HStack(alignment: .center) {
                            Text("Durasi")
                                .font(.headline)
                                .accessibilityHidden(true)
                               
                            Spacer()
                           
                            Picker("Pilih Durasi", selection: $durationMinutes) {
                                Text("1 menit").tag(1)
                                Text("2 menit").tag(2)
                                Text("3 menit").tag(3)
                                Text("5 menit").tag(5)
                                Text("10 menit").tag(10)
           
                            }
                            .tint(Color.white)
                            .pickerStyle(.menu)
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .background(Color.darkBlue2)
                            .cornerRadius(24)
                            .shadow(color: Color.darkBlue3, radius: 0, x: 0, y: 4)
                        }

                        HStack(alignment: .top, spacing: 40) {
                            Text("Distraksi simulasi").font(.headline)
                                .accessibilityHidden(true)
                           
                            VStack(spacing: 4) {
                                Slider(value: $distractionLevel, in: 0...2, step: 1)
                                    .tint(.darkBlue)
                                    .onChange(of: distractionLevel) { v, i in
                                        distractionLevel = v.rounded()
                                    }
                                    .accessibilityElement(children: .ignore)
                                    .accessibilityLabel("Pilih tingkat distraksi suara")
                                    .accessibilityHint("Tap 2 kali lalu geser dengan satu jari untuk mengatur nilai")
                                    .accessibilityValue(
                                            distractionLevel == 0 ? "Rendah" :
                                            distractionLevel == 1 ? "Sedang" : "Tinggi"
                                    )
                               
                                HStack {
                                    VStack(alignment: .center) {
                                        Circle()
                                            .frame(width: 8, height: 8)
                                        Text("Rendah")
                                    }
                                   
                                    Spacer()
                                   
                                    VStack(alignment: .center) {
                                        Circle()
                                            .frame(width: 8, height: 8)
                                        Text("Sedang")
                                    }
                                   
                                    Spacer()
                                   
                                    VStack(alignment: .center) {
                                        Circle()
                                            .frame(width: 8, height: 8)
                                        Text("Tinggi")
                                    }
                                }
                                .font(.subheadline)
                                .foregroundStyle(.baseColorWhite)
                                .accessibilityHidden(true)
                            }
                        }
                       
                        HStack {
                            Text("Aspek yang dievaluasi")
                                .font(.headline)
                                .accessibilityLabel("Pilih aspek yang ingin dievaluasi")
                           
                            Spacer()
                           
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    showAspectInfo = true
                                }
                            }) {
                                Image(systemName: "info.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(Color.baseColorWhite)
                            }
                            .accessibilityLabel("Info aspek")
                        }

                        HStack {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(aspectOptions) { opt in
                                        AspectCheckTile(
                                            option: opt,
                                            isSelected: Binding(
                                                get: { selectedAspects.contains(opt) },
                                                set: { shouldSelect in
                                                    if shouldSelect {
                                                        handleAspectSelection(for: opt)
                                                    } else {
                                                        selectedAspects.remove(opt)
                                                    }
                                                }
                                            )
                                        )
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                            Spacer()
                        }
                       
                        HStack {
                            Spacer()
                            if shouldDisableNext {
                                ButtonComponent(
                                    title: "Pilih Aspek",
                                    systemImage: nil,
                                    size: .medium,
                                    kind: .primaryYellow,
                                    isEnabled: !shouldDisableNext,
                                    action: {
                                        let settings = PracticeSettings(
                                            durationMinutes: durationMinutes,
                                            distractionLevel: distractionLevel,
                                            selectedAspects: selectedAspects
                                        )
                                        onNext(settings)
                                    }
                                )
                                .accessibilityLabel("Pilih aspek untuk lanjut simulasi")
                            } else {
                                ButtonComponent(
                                    title: "Mulai Latihan",
                                    systemImage: nil,
                                    size: .medium,
                                    kind: .primaryYellow,
                                    isEnabled: true,
                                    action: {
                                        let settings = PracticeSettings(
                                            durationMinutes: durationMinutes,
                                            distractionLevel: distractionLevel,
                                            selectedAspects: selectedAspects
                                        )
                                        onNext(settings)
                                    }
                                )
                            }
                        }
                       
                    }
                    .accessibilitySortPriority(1)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(.top, 24)
            .background(Color.baseColorBlue)
            .foregroundStyle(Color.baseColorWhite)
            .navigationBarBackButtonHidden(true)
           
            ButtonComponent(
                title: nil,
                systemImage: "arrow.uturn.left",
                size: .largeIconCircle,
                kind: .secondaryBlue,
                isEnabled: true,
                action: onBack
            )
            .padding(.top, 16)
            .accessibilityLabel("Kembali")
            .accessibilitySortPriority(3)
           
            if showAspectInfo {
                Color.black.opacity(0.5)
                    .edgesIgnoringSafeArea(.all)
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showAspectInfo = false
                        }
                    }
                    .accessibilityHidden(true)
             
                AspectInfoView(onDismiss: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showAspectInfo = false
                    }
                })
                .transition(.opacity)
                .zIndex(1)
                .accessibilityAddTraits(.isModal)
            }
        }
        .alert("Izin Diperlukan", isPresented: $showPermissionAlert) {
            Button("Batal", role: .cancel) { }
            Button("Buka Pengaturan") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
        } message: {
            Text(alertMessage)
        }
    }
    
    private func handleAspectSelection(for option: AspectOption) {
        // Asumsi: 'kontakMata' adalah nama case di enum AspectOption kamu.
        // Jika namanya berbeda (misal: .eyeContact), silakan sesuaikan di baris bawah ini.
        if option == .kontakMata {
            requestCameraAndMicrophone(for: option)
        } else {
            requestMicrophoneOnly(for: option)
        }
    }
    
    // MARK: - Logic 1: Hanya Mic (untuk aspek selain kontak mata)
    private func requestMicrophoneOnly(for option: AspectOption) {
        let status = AVAudioApplication.shared.recordPermission
        
        switch status {
        case .granted:
            selectedAspects.insert(option)
            
        case .denied:
            alertMessage = "Aspek ini memerlukan analisis suara. Harap izinkan akses mikrofon di Pengaturan."
            showPermissionAlert = true
            
        case .undetermined:
            AVAudioApplication.requestRecordPermission { granted in
                DispatchQueue.main.async {
                    if granted {
                        self.selectedAspects.insert(option)
                    }
                }
            }
        @unknown default:
            break
        }
    }
    
    private func requestCameraAndMicrophone(for option: AspectOption) {
        let micStatus = AVAudioApplication.shared.recordPermission
        
        switch micStatus {
        case .granted:
            checkCameraPermission(for: option)
            
        case .denied:
            alertMessage = "Fitur Kontak Mata memerlukan akses Mikrofon dan Kamera. Harap izinkan di Pengaturan."
            showPermissionAlert = true
            
        case .undetermined:
            AVAudioApplication.requestRecordPermission { granted in
                DispatchQueue.main.async {
                    if granted {
                        self.checkCameraPermission(for: option)
                    } else {
                    }
                }
            }
        @unknown default:
            break
        }
    }
    
    private func checkCameraPermission(for option: AspectOption) {
        let cameraStatus = AVCaptureDevice.authorizationStatus(for: .video)
        
        switch cameraStatus {
        case .authorized:
            selectedAspects.insert(option)
            
        case .denied, .restricted:
            alertMessage = "Fitur Kontak Mata memerlukan akses Kamera. Harap izinkan di Pengaturan."
            showPermissionAlert = true
            
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted {
                        self.selectedAspects.insert(option)
                    }
                }
            }
        @unknown default:
            break
        }
    }
}
