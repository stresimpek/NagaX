//
//  SetupPaperCard.swift
//  PublicSpeakingAPP
//
//  Created by Regina Celine Adiwinata on 02/12/25.
//

import SwiftUI

struct SetupPaperCard<Content: View>: View {
    let geo: GeometryProxy
    let content: () -> Content

    init(geo: GeometryProxy,
         @ViewBuilder content: @escaping () -> Content) {
        self.geo = geo
        self.content = content
    }

    var body: some View {
        let paperWidth = geo.size.width * 0.85
        
        if isIpad {
            ZStack(alignment: .topLeading) {
                Image("SetupPaper")
                    .resizable()
                    .frame(width: 784, height: 434)
                    .accessibilityHidden(true)
                
                VStack(spacing: 0) {
                    content()
                        .padding(.horizontal, 20)
                }
                .frame(width: 784, height: 434)
            }
        } else {
            ZStack(alignment: .topLeading) {
                Image("SetupPaper")
                    .resizable()
                    .scaledToFit()
                    .frame(width: paperWidth)
                    .accessibilityHidden(true)
                
                VStack(spacing: 0) {
                    content()
                }
                .frame(width: paperWidth)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
