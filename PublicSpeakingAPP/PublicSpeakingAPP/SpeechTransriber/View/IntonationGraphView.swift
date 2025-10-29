//
//  IntonationGraphView.swift
//  PublicSpeakingAPP
//
//  Created by Regina Celine Adiwinata on 13/10/25.
//

//import SwiftUI
//
//struct IntonationGraphView: View {
//    @ObservedObject var viewModel: IntonationAnalyzerViewModel
//
//    var body: some View {
//        VStack(alignment: .leading) {
//            HStack {
//                Text("📈 Real-time Intonation").font(.headline)
//                Spacer()
//                // Tampilkan label monotonitas
//                Text(viewModel.intonationLabel)
//                    .font(.subheadline).bold()
//                    .foregroundColor(.blue)
//            }
//            
//            // Tampilan Grafik
//            ZStack {
//                if viewModel.pitchHistory.isEmpty {
//                    Text("Speak to see your intonation graph...")
//                        .font(.subheadline)
//                        .foregroundColor(.secondary)
//                } else {
//                    IntonationShape(pitches: viewModel.pitchHistory.)
//                        .stroke(Color.blue, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
//                        .animation(.linear(duration: 0.1), value: viewModel.pitchHistory)
//                }
//            }
//            .frame(height: 150)
//            .padding(.vertical, 8)
//            .background(Color(UIColor.systemGray6))
//            .cornerRadius(8)
//        }
//    }
//}
//
//// Shape custom untuk menggambar grafik (Sama seperti sebelumnya)
//struct IntonationShape: Shape {
//    var pitches: [Double]
//
//    func path(in rect: CGRect) -> Path {
//        var path = Path()
//
//        guard pitches.count > 1 else { return path }
//
//        // Atur rentang Y agar tidak terlalu fluktuatif
//        let minPitch = pitches.min() ?? 80.0
//        let maxPitch = pitches.max() ?? 350.0
//        let pitchRange = (maxPitch - minPitch) > 0 ? (maxPitch - minPitch) : 1
//
//        for (index, pitch) in pitches.enumerated() {
//            let x = rect.width * CGFloat(index) / CGFloat(pitches.count - 1)
//            // Gunakan clamp untuk memastikan nilai y tetap dalam batas
//            let normalizedY = (CGFloat(pitch) - CGFloat(minPitch)) / CGFloat(pitchRange)
//            let clampedY = max(0, min(1, normalizedY))
//            let y = rect.height - (rect.height * clampedY)
//
//            if index == 0 {
//                path.move(to: CGPoint(x: x, y: y))
//            } else {
//                path.addLine(to: CGPoint(x: x, y: y))
//            }
//        }
//        return path
//    }
//}
