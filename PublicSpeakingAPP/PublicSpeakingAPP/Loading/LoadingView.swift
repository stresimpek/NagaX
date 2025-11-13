//
//  LoadingView.swift
//  PublicSpeakingAPP
//
//  Created by Jordan on 23/10/25.
//

import SwiftUI
import WhisperKit

struct LoadingView: View {
    @EnvironmentObject private var whisperKitVM: SpeechTranscriberViewModel

    private var statusText: String {
        switch whisperKitVM.modelState {
        case .downloading:
            return "Downloading model..."
        case .prewarming, .loading:
            return "Preparing model..."
        case .downloaded:
            return "Download complete. Loading..."
        case .unloaded:
            return "Initializing..."
        default:
            return "Loading..."
        }
    }
    
    var body: some View {
        ZStack {
            Color("DarkBlue")
                .ignoresSafeArea()
            
            VStack(spacing: 10) {
                Spacer()
                Spacer()
                
                Image("BelugaLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 120, height: 120)
                    .cornerRadius(20)
                
                Text("CAKO")
                    .font(.title1)
                    .fontWeight(.black)
                    .foregroundColor(.white)
                    .padding(.bottom, 10)
                
                VStack(spacing: 8) {
                    Text(statusText)
                        .foregroundColor(.white)
                        .font(.footnote)
                        .frame(maxWidth: .infinity, alignment: .leading)
                         
                    let progress = whisperKitVM.loadingProgressValue
                    let barHeight: CGFloat = 18
                    
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            
                            Capsule()
                                .fill(Color.black.opacity(0.2))
                                .frame(height: barHeight)
                            
                            Capsule()
                                .fill(Color("Turqoise"))
                                .frame(width: geometry.size.width * CGFloat(progress), height: barHeight)
                        }
                        .overlay(
                            Text(String(format: "%.0f%%", progress * 100))
                                .foregroundColor(.white)
                                .font(.caption.weight(.bold))
                                .padding(.trailing, 10),
                            alignment: .trailing
                        )
                    }
                    .frame(height: barHeight)
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 50)
            }
        }
        .onAppear {
            whisperKitVM.onAppear()
            preloadSettingAssets()
        }
    }
    
    private func preloadSettingAssets() {
        Task(priority: .background) {
            _ = UIImage(named: "ruangKelas")
            _ = UIImage(named: "SetupPaper")
            _ = UIImage(named: "AspectTempo")
            _ = UIImage(named: "AspectFiller")
            _ = UIImage(named: "AspectIntonasi")
            _ = UIImage(named: "AspectEye")
            _ = UIImage(named: "AspectArtikulasi")
            _ = UIImage(named: "AspectStruktur")
            _ = UIImage(named: "LoadingImage")
            
            _ = UIColor(named: "BaseColorBlue")
            _ = UIColor(named: "BaseColorBrown")
            _ = UIColor(named: "BaseColorWhite")
            _ = UIColor(named: "darkBlue")
            _ = UIColor(named: "darkBlue2")
            _ = UIColor(named: "darkBlue3")
            _ = UIColor(named: "BaseColorYellow")
            _ = UIColor(named: "yellow2")
        }
    }
}
