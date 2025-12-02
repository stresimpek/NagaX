//
//  Font.swift
//  PublicSpeakingAPP
//
//  Created by Elisabeth Levana on 10/11/25.
//

import SwiftUI

extension Font {
    static let title1 = Font.custom("Nunito-ExtraBold", size: 20)
    static let title2 = Font.custom("Nunito-Medium", size: 20)
    static let title3 = Font.custom("Nunito-Black", size: 17)
    static let body = Font.custom("Nunito-Medium", size: 17)
    static let subheadline = Font.custom("Nunito-Medium", size: 15)
    static let subheadlineBold = Font.custom("Nunito-ExtraBold", size: 15)
    static let footnoteBold = Font.custom("Nunito-ExtraBold", size: 14)
    static let footnote = Font.custom("Nunito-Medium", size: 14)
    static let captionBold = Font.custom("Nunito-Bold", size: 12)
    static let caption = Font.custom("Nunito-Regular", size: 12)
    static let label = Font.custom("Nunito-Medium", size: 10)
}

extension View {
    var isIpad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }
}
