//
//  SettingsView.swift
//  PublicSpeakingAPP
//
//  Created by Regina Celine Adiwinata on 22/10/25.
//

import SwiftUI
import AVFoundation

struct SettingsView: View {
    @State private var maxTileHeight: CGFloat = 0
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
    
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    private var isAccessibilitySize: Bool {
        dynamicTypeSize.isAccessibilitySize
    }

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
                        .frame(width: dynamicTypeSize.isAccessibilitySize ? 200 : 280)
                        .padding(.leading, dynamicTypeSize.isAccessibilitySize ? 8 : 12)
                        .accessibilitySortPriority(2)
                    ScrollView {                        

                        VStack(alignment: .leading, spacing: 18) {
                            HStack(alignment: .top) {
                                Text("Durasi")
                                    .font(.headline)
                                    .fixedSize(horizontal: false, vertical: true)
//                                    .lineLimit(2)
//                                    .minimumScaleFactor(0.7)
                                    .layoutPriority(1)
                                    .accessibilityHidden(true)
                               
                            Spacer()
                               
                                Picker("Pilih Durasi", selection: $durationMinutes) {
                                    Text("1 menit").tag(1)
                                    Text("2 menit").tag(2)
                                    Text("3 menit").tag(3)
                                    Text("5 menit").tag(5)
                                    Text("10 menit").tag(10)
                
                                }
                                .frame(minWidth: dynamicTypeSize.isAccessibilitySize ? 120 : 90)
                                .tint(Color.white)
                                .pickerStyle(.menu)
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 6)
                                .background(Color.darkBlue2)
                                .cornerRadius(24)
                                .shadow(color: Color.darkBlue3, radius: 0, x: 0, y: 4)
                            }

                            // MARK: - Distraksi simulasi
                            if isAccessibilitySize {
                                // ⚠️ Mode teks besar: label di atas, slider di bawah
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Distraksi simulasi")
                                        .font(.headline)
//                                        .lineLimit(2)
//                                        .minimumScaleFactor(0.7)
                                        .fixedSize(horizontal: false, vertical: true)
                                    
                                    VStack(spacing: 4) {
                                        Slider(value: $distractionLevel, in: 0...2, step: 1)
                                            .tint(.darkBlue)
                                            .onChange(of: distractionLevel) { v, _ in
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
                                            VStack {
                                                Circle().frame(width: 8, height: 8)
                                                Text("Rendah")
                                            }
                                            Spacer()
                                            VStack {
                                                Circle().frame(width: 8, height: 8)
                                                Text("Sedang")
                                            }
                                            Spacer()
                                            VStack {
                                                Circle().frame(width: 8, height: 8)
                                                Text("Tinggi")
                                            }
                                        }
                                        .font(.subheadline)
                                        .foregroundStyle(.baseColorWhite)
                                        .accessibilityHidden(true)
                                    }
                                }
                            } else {
                                HStack(alignment: .top, spacing: 40) {
                                    Text("Distraksi simulasi")
                                        .font(.headline)
//                                        .lineLimit(2)
//                                        .minimumScaleFactor(0.7)
                                        .fixedSize(horizontal: false, vertical: true)
                                        .layoutPriority(1)
                                        .accessibilityHidden(true)
                                    
                                    VStack(spacing: 4) {
                                        Slider(value: $distractionLevel, in: 0...2, step: 1)
                                            .tint(.darkBlue)
                                            .onChange(of: distractionLevel) { v, _ in
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
                                            VStack {
                                                Circle().frame(width: 8, height: 8)
                                                Text("Rendah")
                                            }
                                            Spacer()
                                            VStack {
                                                Circle().frame(width: 8, height: 8)
                                                Text("Sedang")
                                            }
                                            Spacer()
                                            VStack {
                                                Circle().frame(width: 8, height: 8)
                                                Text("Tinggi")
                                            }
                                        }
                                        .font(.subheadline)
                                        .foregroundStyle(.baseColorWhite)
                                        .accessibilityHidden(true)
                                    }
                                }
                            }
                            
                            HStack {
                                Text("Aspek yang dievaluasi")
                                    .font(.headline)
//                                    .lineLimit(2)
//                                    .minimumScaleFactor(0.7)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .accessibilityLabel("Pilih aspek yang ingin dievaluasi")
                            
                                Spacer()
                                
                                Button(action: {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        showAspectInfo = true
                                    }
                                }) {
                                    Image(systemName: "info.circle.fill")
                                        .font(.title)
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
                                                ),
                                                fixedHeight: maxTileHeight == 0 ? nil : maxTileHeight
                                            )
                                        }
                                    }
                                    .padding(.vertical, 4)
                                }
                                .onPreferenceChange(AspectTileHeightPreferenceKey.self) { height in
                                    if height > 0 {
                                        maxTileHeight = height
                                    }
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
                        .padding(.leading, dynamicTypeSize.isAccessibilitySize ? 0 : 8)
                        .padding(.trailing, 16)
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
        if option == .kontakMata {
            requestCameraAndMicrophone(for: option)
        } else {
            requestMicrophoneOnly(for: option)
        }
    }
    
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
