//
//  EyeContactViewModel.swift
//  PublicSpeakingAPP
//
//  Created by Jordan on 26/11/25.
//

import Foundation
import Combine

struct GazeLogItem: Identifiable, Hashable {
    let id = UUID()
    let timestamp: TimeInterval
    let event: String
}

@MainActor
class EyeContactViewModel: ObservableObject {
    
    @Published var eyeContactRating: Int = 3
    @Published var statusLabel: String = "Kontak Mata Bagus"
    @Published var feedbackMessage: String = ""
    @Published var issueHistory: [GazeLogItem] = []
    
    private var badEventCounter: Int = 0
    private let badEventThreshold: Int = 2
    
    private var currentActiveEvent: HeadGazeEvent? = nil
    
    func processEvent(_ event: HeadGazeEvent, at timestamp: TimeInterval) {
        
        switch event {
        case .normal:
            badEventCounter = 0
            if currentActiveEvent != nil {
                currentActiveEvent = nil
                print("[EyeContactVM] Recovered to Normal")
            }
            
            if eyeContactRating != 3 {
                eyeContactRating = 3
                statusLabel = "Kontak Mata Bagus"
                feedbackMessage = ""
            }
            
        case .headPitchUp, .headPitchDown, .gazeUp, .gazeDown:
            if let active = currentActiveEvent, active == event {
                return
            }
            
            if let active = currentActiveEvent {
                if active == .headPitchUp && event == .gazeUp {
                    return
                }
                if active == .headPitchDown && event == .gazeDown {
                    return
                }
            }
            
            badEventCounter += 1
            
            if badEventCounter >= badEventThreshold {
                
                if eyeContactRating != 1 {
                    eyeContactRating = 1
                }
                
                updateStatusLabel(for: event)
                currentActiveEvent = event
                
                let issueText = mapEventToString(event)
                let newLog = GazeLogItem(timestamp: timestamp, event: issueText)
                issueHistory.append(newLog)
                
                print("[EyeContactVM] Logged: \(issueText) at \(timestamp)")
            }
        }
    }
    
    private func updateStatusLabel(for event: HeadGazeEvent) {
        switch event {
        case .headPitchUp:
            statusLabel = "Kepala Terlalu Naik"
            feedbackMessage = "Turunkan dagu sedikit."
        case .headPitchDown:
            statusLabel = "Kepala Menunduk"
            feedbackMessage = "Angkat kepala, lihat audiens."
        case .gazeUp:
            statusLabel = "Mata Melihat Atas"
            feedbackMessage = "Fokus ke depan."
        case .gazeDown:
            statusLabel = "Mata Melihat Bawah"
            feedbackMessage = "Hindari membaca teks terus menerus."
        default:
            break
        }
    }
    
    private func mapEventToString(_ event: HeadGazeEvent) -> String {
        switch event {
        case .headPitchUp: return "HeadUp"
        case .headPitchDown: return "HeadDown"
        case .gazeUp: return "GazeUp"
        case .gazeDown: return "GazeDown"
        default: return "Normal"
        }
    }
    
    func clearResults() {
        eyeContactRating = 3
        statusLabel = "Kontak Mata Bagus"
        feedbackMessage = ""
        badEventCounter = 0
        currentActiveEvent = nil
        issueHistory.removeAll()
    }
}
