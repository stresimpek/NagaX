//
//  MicroAnimation.swift
//  PublicSpeakingAPP
//
//  Created by Regina Celine Adiwinata on 18/11/25.
//

import SwiftUI
import RiveRuntime

struct MicroAnimation: View {
    private let rive: RiveViewModel

    init(
        artboardName: String? = nil
    ) {
        self.rive = RiveViewModel(
            fileName: "microAnimation",
            autoPlay: true,
            artboardName: artboardName
        )
    }

    var body: some View {
        rive.view()
    }
}
