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

                    VStack(alignment: .leading, spacing: 18) {
                        HStack(alignment: .center) {
                            Text("Durasi")
                                .font(.headline)
                            Spacer()
                           
                            Picker("Durasi", selection: $durationMinutes) {
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
                            
                            VStack(spacing: 4) {
                                Slider(value: $distractionLevel, in: 0...2, step: 1)
                                    .tint(.darkBlue)
                                    .onChange(of: distractionLevel) { v, i in
                                        distractionLevel = v.rounded()
                                    }
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
                            }
                        }
                        
                        HStack {
                            Text("Aspek yang dievaluasi")
                                .font(.headline)
                            
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
            
            if showAspectInfo {
                Color.black.opacity(0.5)
                    .edgesIgnoringSafeArea(.all)
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showAspectInfo = false
                        }
                    }
                
                AspectInfoView(onDismiss: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showAspectInfo = false
                    }
                })
                .transition(.opacity)
            }
        }
        .alert("Izin Mikrofon Diperlukan", isPresented: $showPermissionAlert) {
                Button("Batal", role: .cancel) { }
                Button("Buka Pengaturan") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
            } message: {
                Text("Aspek yang kamu pilih memerlukan analisis suara. Harap izinkan akses mikrofon di Pengaturan.")
            }
    }
    
    private func handleAspectSelection(for option: AspectOption) {
        let status = AVAudioApplication.shared.recordPermission
        
        switch status {
        case .granted:
            selectedAspects.insert(option)
            
        case .denied:
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
}
