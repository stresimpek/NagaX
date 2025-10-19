//
//  AppDelegate.swift
//  PublicSpeakingAPP
//
//  Created by Jordan on 20/10/25.
//

// AppDelegate.swift

import UIKit
import SwiftUI

class AppDelegate: UIResponder, UIApplicationDelegate {
    
    var orientationInfo = OrientationInfo()

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        return true
    }

    // --- KEMBALIKAN KE VERSI INI ---
    // Ini adalah Sinyal "Peta".
    // Kita memberi tahu iOS bahwa satu-satunya orientasi yang diizinkan
    // adalah nilai yang saat ini ada di orientationInfo.
    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        return orientationInfo.orientation
    }
}
