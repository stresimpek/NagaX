//
//  TempoView.swift
//  PublicSpeakingAPP
//
//  Created by Feby Agatha Christie Kurniawan on 20/10/25.
//

import SwiftUI

struct TempoView: View {
    @ObservedObject var viewModel: TempoViewModel

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text("Tempo Bicara (WPM)")
                    .font(.headline)
                
                Spacer()
                
                Text(viewModel.tempoLabel)
                    .font(.subheadline).bold()
                    .foregroundColor(.blue)
            }
            
            Text(String(format: "%.0f", viewModel.wpm))
                .font(.system(size: 48, weight: .bold))
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 20)
        }
        .padding()
        .background(Color(UIColor.systemGray6))
        .cornerRadius(8)
    }
}
