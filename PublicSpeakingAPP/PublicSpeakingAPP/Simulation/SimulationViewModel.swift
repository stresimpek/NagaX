//
//  SimulationViewModel.swift
//  PublicSpeakingAPP
//
//  Created by Jordan on 20/10/25.
//

import Foundation
import Combine

class SimulationViewModel: ObservableObject {
    
    @Published var teacherMood: TeacherMood = .idle
    @Published var studentMoods: [StudentMood] = Array(repeating: .idle, count: 9)
    @Published var timerSeconds: Int = 0
    @Published var isRecording: Bool = false
    
    var formattedTime: String {
        let minutes = timerSeconds / 60
        let seconds = timerSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    private var gameTimer: Timer?
    
    func toggleRecording() {
        isRecording.toggle()
        
        if isRecording {
            startGame()
        } else {
            stopGame()
        }
    }
    
    func setTeacherMood(_ mood: TeacherMood) {
        if self.teacherMood == mood && self.isRecording {
            self.teacherMood = .idle
            DispatchQueue.main.async {
                self.teacherMood = mood
            }
        } else {
            self.teacherMood = mood
        }
    }
    
    func setStudentMoods(_ mood: StudentMood) {
        if self.studentMoods.first == mood && self.isRecording {
            self.studentMoods = Array(repeating: .idle, count: 9)
            DispatchQueue.main.async {
                self.studentMoods = Array(repeating: mood, count: 9)
            }
        } else {
            self.studentMoods = Array(repeating: mood, count: 9)
        }
    }
    
    private func startGame() {
        resetGame()
                self.teacherMood = .idle
        self.studentMoods = Array(repeating: .idle, count: 9)
        
        gameTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateGameLogic()
        }
    }
    
    private func stopGame() {
        gameTimer?.invalidate()
        gameTimer = nil
        
        self.teacherMood = .idle
        self.studentMoods = Array(repeating: .idle, count: 9)
        
        resetGame()
    }
    
    private func resetGame() {
        timerSeconds = 0
    }
    
    private func updateGameLogic() {
        timerSeconds += 1
    }
}
