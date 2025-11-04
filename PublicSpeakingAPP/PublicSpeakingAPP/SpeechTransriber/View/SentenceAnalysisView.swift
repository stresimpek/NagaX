//
//  SentenceAnalysisView.swift
//  PublicSpeakingAPP
//
//  Created by Feby Agatha Christie Kurniawan on 03/11/25.
//

import SwiftUI

enum AnalysisType: String, CaseIterable {
    case transcript = "Hasil Transkrip"
    case correction = "Hasil Koreksi"
}

struct SentenceAnalysisView: View {
    @ObservedObject var viewModel: SpeechTranscriberViewModel
    @State private var selectedTab: AnalysisType = .transcript
    
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
                
            } else if let analysis = viewModel.SentenceAnalysis {
                // Tampilan hasil (UI seperti gambar Anda)
                
                // Pesan ringkasan
                Text("Hmm... ketahuan nih 🧐 Ada **\(analysis.totalErrors) penggunaan kata yang tidak memebuhi kaidah Kehematan.** Tapi good job! Kamu sudah latihan.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                // TAB: "Hasil Transkrip" / "Hasil Koreksi"
                Picker("Pilih Tampilan", selection: $selectedTab) {
                    ForEach(AnalysisType.allCases, id: \.self) {
                        Text($0.rawValue).tag($0)
                    }
                }
                .pickerStyle(.segmented)
                
                // KONTEN TEKS (Merah/Biru)
                ScrollView {
                    // Menggunakan reduce untuk menggabungkan Text view
                    // Ini adalah cara untuk memiliki teks dengan warna berbeda dalam satu paragraf
                    analysis.segments.reduce(Text(""), { combinedText, segment in
                        combinedText + Text(formattedText(for: segment)) + Text(" ")
                    })
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
                Text(viewModel.SentenceAnalysis == nil ? "Mulai Analisis" : "Analisis Ulang")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green) // Cocokkan dengan tombol di view sebelumnya
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .disabled(viewModel.isAnalyzingSentence || viewModel.transcript.isEmpty)
        }
        .padding()
    }
    
    private func formattedText(for segment: SentenceSegment) -> AttributedString {
        var attributes = AttributeContainer()
        var textToUse: String
        
        switch selectedTab {
        case .transcript:
            // Tampilan Transkrip: Merah jika salah, hitam jika benar
            textToUse = segment.original
            if segment.isCorrected {
                attributes.foregroundColor = .red
                attributes.strikethroughStyle = .single // Tambahkan coretan
            } else {
                attributes.foregroundColor = .primary
            }
            
        case .correction:
            // Tampilan Koreksi: Biru jika dikoreksi, hitam jika tetap
            textToUse = segment.correction ?? segment.original
            if segment.isCorrected {
                attributes.foregroundColor = .blue // Gunakan biru untuk koreksi
                attributes.font = .body.bold() // Buat tebal
            } else {
                attributes.foregroundColor = .primary
            }
        }
        
        return AttributedString(textToUse, attributes: attributes)
    }
}
