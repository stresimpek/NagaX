//
//  HeadGazeEvent.swift
//  PublicSpeakingAPP
//
//  Created by Jordan on 14/11/25.
//

import Foundation

/// Mendefinisikan status pelanggaran kepala atau pandangan mata.
enum HeadGazeEvent {
    case normal           // Semua normal
    case headPitchUp      // Kepala mendongak
    case headPitchDown    // Kepala menunduk
    case gazeUp           // Mata lihat ke atas
    case gazeDown         // Mata lihat ke bawah
}
