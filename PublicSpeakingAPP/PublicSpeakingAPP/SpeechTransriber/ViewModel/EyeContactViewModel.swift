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
    let startTime: TimeInterval
    let endTime: TimeInterval
    let event: String
    
    var duration: TimeInterval {
        return endTime - startTime
    }
}

@MainActor
class EyeContactViewModel: ObservableObject {
    
    @Published var eyeContactRating: Int = 3
    @Published var statusLabel: String = "Kontak Mata Bagus"
    @Published var feedbackMessage: String = ""
    @Published var issueHistory: [GazeLogItem] = []
    
    private var badEventCounter: Int = 0
    private let badEventThreshold: Int = 2
    
    private var currentEventStartTime: TimeInterval? = nil
    private var currentActiveEvent: HeadGazeEvent? = nil
    
    func processEvent(_ event: HeadGazeEvent, at timestamp: TimeInterval) {
        
        if let active = currentActiveEvent {
            if (active == .headPitchUp || active == .headPitchDown) && (event == .gazeUp || event == .gazeDown) {
                handleStateChange(newState: active, at: timestamp)
                return
            }
        }
        
        handleStateChange(newState: event, at: timestamp)
    }
    
    private func handleStateChange(newState: HeadGazeEvent, at timestamp: TimeInterval) {
        
        if newState != currentActiveEvent {
            
            if let activeEvent = currentActiveEvent, let startTime = currentEventStartTime {
                
                if (timestamp - startTime) > 0.5 {
                    let issueText = mapEventToString(activeEvent)
                    let newLog = GazeLogItem(
                        startTime: startTime,
                        endTime: timestamp,
                        event: issueText
                    )
                    issueHistory.append(newLog)
                    print("[EyeContactVM] CLIP SAVED: \(issueText) | \(startTime) -> \(timestamp)")
                }
            }
            
            if newState == .normal {
                currentActiveEvent = nil
                currentEventStartTime = nil
                badEventCounter = 0
                
                resetUI()
                
            } else {
                badEventCounter += 1
                
                if badEventCounter >= badEventThreshold {
                    currentActiveEvent = newState
                    currentEventStartTime = timestamp
                    
                    updateUI(for: newState)
                }
            }
        }
        else {
            if currentActiveEvent == nil && newState != .normal {
                badEventCounter += 1
                if badEventCounter >= badEventThreshold {
                    currentActiveEvent = newState
                    currentEventStartTime = timestamp
                    updateUI(for: newState)
                }
            }
        }
    }
    
    func finalizeSession(at finalTimestamp: TimeInterval) {
        if let activeEvent = currentActiveEvent, let startTime = currentEventStartTime {
            let issueText = mapEventToString(activeEvent)
            let newLog = GazeLogItem(
                startTime: startTime,
                endTime: finalTimestamp,
                event: issueText
            )
            issueHistory.append(newLog)
        }
    }
    
    private func updateUI(for event: HeadGazeEvent) {
        if eyeContactRating != 1 { eyeContactRating = 1 }
        
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
        default: break
        }
    }
    
    private func resetUI() {
        if eyeContactRating != 3 {
            eyeContactRating = 3
            statusLabel = "Kontak Mata Bagus"
            feedbackMessage = ""
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
        currentEventStartTime = nil
        issueHistory.removeAll()
    }
}
