//
//  SettingsView.swift
//  PublicSpeakingAPP
//
//  Created by Regina Celine Adiwinata on 22/10/25.
//
import SwiftUI

struct SettingsView: View {
    
    @State private var durationMinutes: Int = 5
    @State private var distractionLevel: Double = 0.0
    @State private var enableQnA: Bool = false
    @State private var randomTopic: Bool = false
    
    let onBack: () -> Void
    let onNext: (PracticeSettings) -> Void

    private let aspectOptions: [AspectOption] = AspectOption.allOptions

    @State private var selectedAspects: Set<AspectOption> = []
    
    private var shouldDisableNext: Bool {
        selectedAspects.isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            SettingsHeader(
                title: "Pilih tempat presentasimu",
                onBack: onBack,
                onNext: {
                    let settings = PracticeSettings(
                        durationMinutes: durationMinutes,
                        distractionLevel: distractionLevel,
                        enableQnA: enableQnA,
                        randomTopic: randomTopic,
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

                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .center) {
                        Text("Durasi")
                            .font(.headline)
                        Spacer()
                        Text("\(durationMinutes) menit")
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(.gray.opacity(0.25))
                            .clipShape(Capsule())
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Distraksi").font(.headline)
                            Spacer()
                            VStack(spacing: 4) {
                                Slider(value: $distractionLevel, in: 0...2, step: 1)
                                    .tint(.blue)
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
                    }
                    .padding(.vertical, 4)


                    HStack(spacing: 24) {
                        Toggle("QnA", isOn: $enableQnA)
                            .toggleStyle(.switch)
                        Toggle("Random Topik", isOn: $randomTopic)
                            .toggleStyle(.switch)
                    }

                    Divider().padding(.vertical, 4)

                    Text("Aspek yang dievaluasi")
                        .font(.headline)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(aspectOptions) { opt in
                                AspectCheckTile(
                                    option: opt,
                                    isSelected: Binding(
                                        get: { selectedAspects.contains(opt) },
                                        set: { newVal in
                                            if newVal {
                                                selectedAspects.insert(opt)
                                                print("Inserted: \(opt.title). Current selection: \(selectedAspects.map { $0.title })")
                                            }
                                            else {
                                                
                                                selectedAspects.remove(opt)
                                                print("Removed: \(opt.title). Current selection: \(selectedAspects.map { $0.title })")
                                            }
                                        }
                                    )
                                )
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.trailing, 16)
            }
            .padding(.vertical, 12)
        }
        .ignoresSafeArea(edges: .trailing)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.white)
        .navigationBarBackButtonHidden(true)
        .padding(.trailing, 16)
    }
}
