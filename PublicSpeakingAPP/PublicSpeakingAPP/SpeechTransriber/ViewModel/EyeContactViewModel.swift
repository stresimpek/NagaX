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
    let event: String // e.g., "Head Up", "Gaze Down"
}

@MainActor
class EyeContactViewModel: ObservableObject {
    
    // Output ke View/SimulationVM
    @Published var eyeContactRating: Int = 3 {
        didSet {
            print("👀👀👀👀👀👀👀👀👀👀👀👀👀👀\n [EyeContactVM] Rating Berubah: \(oldValue) -> \(eyeContactRating)")
        }
    }
    @Published var statusLabel: String = "Kontak Mata Bagus"
    @Published var feedbackMessage: String = ""
    
    // Log untuk Evaluasi Nanti
    // UPDATED: Menggunakan struct eksternal GazeLogItem agar kompatibel dengan EvaluationView
    @Published var issueHistory: [GazeLogItem] = []
    
    // Internal Logic Variables
    private var badEventCounter: Int = 0
    private let badEventThreshold: Int = 2 // Sesuai request: 2 kali terima event jelek
    
    // Fungsi Utama yang dipanggil dari SimulationViewModel
    func processEvent(_ event: HeadGazeEvent, at timestamp: TimeInterval) {
        
        switch event {
        case .normal:
            // Jika kembali normal, reset counter dan kembalikan nilai ke 3
            badEventCounter = 0
            if eyeContactRating != 3 {
                eyeContactRating = 3
                statusLabel = "Kontak Mata Bagus"
                feedbackMessage = ""
                print("[EyeContactVM] Recovered to Normal (Rating: 3)")
            }
            
        case .headPitchUp, .headPitchDown, .gazeUp, .gazeDown:
            // Jika event buruk, tambah counter
            badEventCounter += 1
            
            // Cek apakah sudah mencapai ambang batas (2x terima event = 1 detik asumsi)
            if badEventCounter >= badEventThreshold {
                if eyeContactRating != 1 {
                    eyeContactRating = 1
                    updateStatusLabel(for: event)
                    
                    // Catat ke history untuk report akhir
                    // UPDATED: Menggunakan GazeLogItem
                    let issueText = mapEventToString(event)
                    let newLog = GazeLogItem(timestamp: timestamp, event: issueText)
                    issueHistory.append(newLog)
                    
                    print("[EyeContactVM] Bad Event Threshold Reached! (Rating: 1) - Cause: \(issueText)")
                }
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
    
    // Helper mapping agar sesuai dengan logika di EyeContactEvaluationView
    // View kamu mengecek: type == "Up" ? ... : ...
    private func mapEventToString(_ event: HeadGazeEvent) -> String {
        switch event {
        case .headPitchUp, .gazeUp:
            return "Up"
        case .headPitchDown, .gazeDown:
            return "Down"
        default:
            return "Normal"
        }
    }
    
    func clearResults() {
        eyeContactRating = 3
        statusLabel = "Kontak Mata Bagus"
        feedbackMessage = ""
        badEventCounter = 0
        issueHistory.removeAll()
    }
}
