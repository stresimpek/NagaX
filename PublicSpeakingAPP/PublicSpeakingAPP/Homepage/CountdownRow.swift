//
//  CountdownRoe.swift
//  PublicSpeakingAPP
//
//  Created by Regina Celine Adiwinata on 04/11/25.
//

import SwiftUI
import Combine

struct CountdownRow: View {
    let targetDate: Date?
    @State private var now = Date()
    
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    private func remaining() -> (d: Int, h: Int, m: Int, done: Bool) {
        guard let target = targetDate else { return (0,0,0,true) }
        let diff = max(0, Int(target.timeIntervalSince(now)))
        if diff == 0 { return (0,0,0,true) }
        let d = diff / 86400
        let h = (diff % 86400) / 3600
        let m = (diff % 3600) / 60
        return (d,h,m,false)
    }
    
    var body: some View {
        let r = remaining()
        
        HStack(spacing: 4) {
            Text("Presentasimu dimulai dalam:")
            CountdownBox(text: "\(r.d)")
            Text("hari")
            CountdownBox(text: "\(r.h)")
            Text("jam")
            CountdownBox(text: "\(r.m)")
            Text("menit")
            Spacer()
        }
        .onReceive(timer) { _ in now = Date() }
        .opacity(r.done ? 0.6 : 1)
    }
}
