//
//  PresentationDateModel.swift
//  PublicSpeakingAPP
//
//  Created by Regina Celine Adiwinata on 04/11/25.
//

import Foundation
import SwiftData

@Model
final class PresentationDateModel {
    @Attribute(.unique) var key: String = "default"
    var date: Date

    init(date: Date) {
        self.date = date
    }
}
