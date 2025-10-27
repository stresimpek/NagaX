//
//  NoTranscriptView.swift
//  PublicSpeakingAPP
//
//  Created by Jordan on 23/10/25.
//

import SwiftUI

struct NoTranscriptView: View {
    let title: String
    let message: String
    @Binding var isPresented: Bool
    
    var body: some View {
        VStack(spacing: 15) {
            Text(title)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text(message)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Divider()
                .padding(.horizontal)
            
            Button(action: {
                withAnimation {
                    isPresented = false
                }
            }) {
                Text("Mengerti")
                    .font(.system(size: 17, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }
        }
        .padding()
        .frame(maxWidth: 300)
        .background(.regularMaterial)
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
        .transition(.scale.combined(with: .opacity))
    }
}
