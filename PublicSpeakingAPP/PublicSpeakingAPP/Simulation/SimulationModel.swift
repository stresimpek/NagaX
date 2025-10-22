//
//  SimulationModel.swift
//  PublicSpeakingAPP
//
//  Created by Jordan on 20/10/25.
//

import Foundation

func generateFrameNames(prefix: String, lastFrame: Int) -> [String] {
    return (1...lastFrame).map { index in
        "\(prefix)_\(index)"
    }
}

enum TeacherMood {
    case idle
    case angry
    case happy
    
    var animationFrames: [String] {
        switch self {
        case .idle:
            return [generateFrameNames(prefix: "teacher_angry", lastFrame: 12).first ?? "teacher_angry_1"]
        case .angry:
            return generateFrameNames(prefix: "teacher_angry", lastFrame: 12)
        case .happy:
            return generateFrameNames(prefix: "teacher_happy", lastFrame: 15)
        }
    }
}

enum StudentMood {
    case idle
    case sleep
    case focus
    
    var animationFrames: [String] {
        switch self {
        case .idle:
            return [generateFrameNames(prefix: "student_sleep", lastFrame: 21).first ?? "student_sleep_1"]
        case .sleep:
            return generateFrameNames(prefix: "student_sleep", lastFrame: 21)
        case .focus:
            return generateFrameNames(prefix: "student_focus", lastFrame: 12)
        }
    }
}
