//
//  SentenceAnalysisView.swift
//  PublicSpeakingAPP
//
//  Created by Feby Agatha Christie Kurniawan on 03/11/25.
//

import SwiftUI

struct SentenceAnalysisView: View {
    @ObservedObject var viewModel: SpeechTranscriberViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            
            // JUDUL
            Text("Analisis Kehematan Kalimat")
                .font(.title)
                .bold()
                .padding(.bottom, 10)

            if viewModel.isAnalyzingSentence {
                // Tampilan loading
                HStack {
                    Spacer()
                    ProgressView()
                    Text("Menganalisis tata bahasa...")
                    Spacer()
                }
                .padding(.vertical, 50)
                
            } else if let error = viewModel.SentenceAnalysisError {
                // Tampilan error
                Text(error)
                    .foregroundColor(.red)
                    .padding()
                
            } else if !viewModel.sentenceAnalysisResult.isEmpty {
                // Tampilan hasil (Teks Biasa)
                ScrollView {
                    Text(viewModel.sentenceAnalysisResult)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .font(.body)
                        .lineSpacing(5)
                }
                .padding()
                .background(Color(UIColor.systemGray6))
                .cornerRadius(10)
                
            } else {
                // Tampilan awal sebelum analisis
                Text("Klik \"Mulai Analisis\" untuk memeriksa transkrip Anda.")
                    .italic()
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 50)
            }
            
            Spacer()
            
            // Tombol Aksi
            Button(action: {
                Task {
                    await viewModel.analyzeTranscriptSentence()
                }
            }) {
                Text(viewModel.sentenceAnalysisResult.isEmpty ? "Mulai Analisis" : "Analisis Ulang")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green) // Cocokkan dengan tombol di view sebelumnya
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .disabled(viewModel.isAnalyzingSentence || viewModel.transcript.isEmpty)
        }
        .padding()
        .onAppear {
             if viewModel.sentenceAnalysisResult.isEmpty {
                 Task {
                     await viewModel.analyzeTranscriptSentence()
                 }
             }
         }
    }
}
