//
//  QuestionGeneratorView.swift
//  PublicSpeakingAPP
//
//  Created by Elisabeth Levana on 23/10/25.
//


import SwiftUI

struct QuestionGeneratorView: View {
    @StateObject private var vm = QuestionGeneratorViewModel()
    let confirmedText: String

    var body: some View {
        VStack(spacing: 20) {
            Text("QnA")
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding(.top)

            // Model loading indicator
            if vm.modelState != .loaded {
                VStack(spacing: 16) {
                    if vm.modelState == .downloading {
                        ProgressView(value: vm.loadingProgress) {
                            Text(vm.downloadStatus)
                                .font(.caption)
                        }
                        .progressViewStyle(.linear)
                        .tint(.blue)
                        .padding(.horizontal, 40)
                        
                        Text("\(Int(vm.loadingProgress * 100))%")
                            .font(.headline)
                            .foregroundColor(.blue)
                    } else if vm.modelState == .loading {
                        ProgressView()
                        Text(vm.downloadStatus)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else if vm.modelState == .failed {
                        VStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.largeTitle)
                                .foregroundColor(.red)
                            Text("Gagal memuat model")
                                .font(.headline)
                            if let error = vm.error {
                                Text(error)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Button("Coba Lagi") {
                                vm.loadModel()
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                }
                .frame(maxHeight: .infinity)
            } else {
                // Display source text excerpt
                VStack(alignment: .leading, spacing: 8) {
                    Text("Berdasarkan transkrip:")
                        .font(.headline)

                    ScrollView {
                        Text(confirmedText)
                            .font(.body)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.systemGray6))
                            .cornerRadius(10)
                    }
                    .frame(maxHeight: 150)
                }
                .padding(.horizontal)

                Divider()

                // Generated questions area
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        if vm.isGenerating {
                            HStack {
                                ProgressView()
                                Text("Menghasilkan pertanyaan...")
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding()
                        } else if !vm.generatedQuestions.isEmpty {
                            Text(vm.generatedQuestions)
                                .font(.body)
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                        } else {
                            Text("Tekan tombol 'Generate' untuk membuat QnA")
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding()
                        }
                    }
                }
                .frame(maxHeight: .infinity)
                .background(Color(.systemBackground))

                // Action buttons
                VStack(spacing: 12) {
                    if vm.generatedQuestions.isEmpty && !vm.isGenerating {
                        Button(action: {
                            vm.generateQuestions(from: confirmedText)
                        }) {
                            HStack {
                                Image(systemName: "sparkles")
                                Text("Generate Pertanyaan")
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                    }

                    Button(action: {
                        // Pop to root (HomeView)
                        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                           let window = windowScene.windows.first,
                           let navigationController = window.rootViewController as? UINavigationController {
                            navigationController.popToRootViewController(animated: true)
                        }
                    }) {
                        Text("Kembali ke Home")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }
                .padding()
            }
        }
        .background(Color(.systemGroupedBackground))
        .onAppear {
            if vm.modelState == .unloaded {
                vm.loadModel()
            } else if vm.modelState == .loaded && vm.generatedQuestions.isEmpty {
                vm.generateQuestions(from: confirmedText)
            }
        }
    }
}
