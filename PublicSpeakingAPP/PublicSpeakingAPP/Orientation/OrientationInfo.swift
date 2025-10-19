//
//  OrientationInfo.swift
//  PublicSpeakingAPP
//
//  Created by Jordan on 20/10/25.
//
// OrientationInfo.swift

// OrientationInfo.swift (SUDAH BENAR, JANGAN DIUBAH)

import Foundation
import UIKit
import SwiftUI

class OrientationInfo: ObservableObject {
    
    @Published var orientation: UIInterfaceOrientationMask = .portrait
    
    func lockToLandscape() {
        print("DEBUG: Mengunci ke Landscape")
        DispatchQueue.main.async {
            // 1. Mengubah "Peta" (memicu AppDelegate)
            self.orientation = .landscape
            // 2. Memberi "Perintah" (memaksa rotasi)
            Self.requestGeometryUpdate(to: .landscape)
        }
    }
    
    func lockToPortrait() {
        print("DEBUG: Mengunci ke Portrait")
        DispatchQueue.main.async {
            // 1. Mengubah "Peta" (memicu AppDelegate)
            self.orientation = .portrait
            // 2. Memberi "Perintah" (memaksa rotasi)
            Self.requestGeometryUpdate(to: .portrait)
        }
    }
    
    private static func requestGeometryUpdate(to mask: UIInterfaceOrientationMask) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else {
            print("ERROR: Gagal menemukan Window Scene")
            return
        }
        
        let geometryPreferences = UIWindowScene.GeometryPreferences.iOS(
            interfaceOrientations: mask
        )
        
        windowScene.requestGeometryUpdate(geometryPreferences) { error in
            
        }
    }
}
