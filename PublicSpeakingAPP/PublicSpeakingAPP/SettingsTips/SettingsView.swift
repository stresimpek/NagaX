//
//  SettingsView.swift
//  PublicSpeakingAPP
//
//  Created by Regina Celine Adiwinata on 22/10/25.
//
import SwiftUI

struct SettingsView: View {
    
    @State private var durationMinutes: Int = 1
    @State private var distractionLevel: Double = 0.0
    @State private var enableQnA: Bool = false
    @State private var randomTopic: Bool = false
    
    // State untuk mengontrol tampilan modal info
    @State private var showAspectInfo: Bool = false
    
    let onBack: () -> Void
    let onNext: (PracticeSettings) -> Void

    private let aspectOptions: [AspectOption] = AspectOption.allOptions
    @State private var selectedAspects: Set<AspectOption> = []
    
    private var shouldDisableNext: Bool {
        selectedAspects.isEmpty || durationMinutes == 0
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                SettingsHeader(
                    onBack: onBack,
                    onNext: {
                        let settings = PracticeSettings(
                            durationMinutes: durationMinutes,
                            distractionLevel: distractionLevel,
//                            enableQnA: enableQnA,
//                            randomTopic: randomTopic,
                            selectedAspects: selectedAspects
                        )
                        onNext(settings)
                    },
                    isNextDisabled: shouldDisableNext
                )

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
                            .background(Color.darkBlue)
                            .cornerRadius(24)
                            .shadow(color: Color.darkBlue2, radius: 0, x: 0, y: 4)
                        }
                        
//                        HStack(spacing: 24) {
//                            Toggle("QnA", isOn: $enableQnA)
//                                .font(.headline)
//                                .toggleStyle(SwitchToggleStyle(tint: .darkBlue))
//                            Spacer()
//                            Toggle("Random Topik", isOn: $randomTopic)
//                                .font(.headline)
//                                .toggleStyle(SwitchToggleStyle(tint: .darkBlue))
//                        }

                        HStack(alignment: .top, spacing: 40) {
                            Text("Distraksi").font(.headline)
                            
                            VStack(spacing: 4) {
                                Slider(value: $distractionLevel, in: 0...2, step: 1)
                                    .tint(.darkBlue)
                                    .onChange(of: distractionLevel) { v, i in
                                        distractionLevel = v.rounded()
                                    }
                                HStack {
                                    Text("tidak ada")
                                    Spacer()
                                    Text("sedikit")
                                    Spacer()
                                    Text("banyak")
                                }
                                .font(.caption)
                                .foregroundStyle(.secondary)
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
                                Image(systemName: "info.circle")
                                    .font(.title3)
                                    .foregroundColor(Color.baseColorWhite)
                            }
                        }

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(aspectOptions) { opt in
                                    AspectCheckTile(
                                        option: opt,
                                        isSelected: Binding(
                                            get: { selectedAspects.contains(opt) },
                                            set: { newVal in
                                                if newVal { selectedAspects.insert(opt) }
                                                else { selectedAspects.remove(opt) }
                                            }
                                        )
                                    )
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(Color.baseColorBlue)
            .foregroundStyle(Color.baseColorWhite)
            .navigationBarBackButtonHidden(true)
            
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
    }
}
