//
//  AnimatedActorView.swift
//  PublicSpeakingAPP
//
//  Created by Jordan on 20/10/25.
//

import SwiftUI
import Combine

struct AnimatedActorView: View {
    let targetFrames: [String]
    let isAnimating: Bool
    let animationInterval: TimeInterval
    @State private var currentFrameIndex = 0
    @State private var framesToPlay: [String]
    @State private var timerSubscription: AnyCancellable?
    @State private var onAnimationComplete: (() -> Void)? = nil

    init(targetFrames: [String], isAnimating: Bool, interval: TimeInterval = 0.1) {
        self.targetFrames = targetFrames
        self.isAnimating = isAnimating
        self.animationInterval = interval
        self._framesToPlay = State(initialValue: targetFrames)
    }

    private var safeFrameIndex: Int {
        if framesToPlay.indices.contains(currentFrameIndex) { return currentFrameIndex }
        else if !framesToPlay.isEmpty { return 0 }
        else { return 0 }
    }
    
    private var currentImageName: String {
        return framesToPlay.isEmpty ? "person.fill" : framesToPlay[safeFrameIndex]
    }

    var body: some View {
        Image(currentImageName)
            .resizable()
            .scaledToFit()
            .onChange(of: targetFrames) { oldTargetFrames, newTargetFrames in
                handleMoodChange(from: oldTargetFrames, to: newTargetFrames)
            }
            .onChange(of: isAnimating) { _, isRecording in
                stopAnimation()
                self.onAnimationComplete = nil
                self.framesToPlay = self.targetFrames
                self.currentFrameIndex = 0
            }
            .onAppear {
                self.framesToPlay = self.targetFrames
                self.currentFrameIndex = 0
                stopAnimation()
            }
            .onDisappear {
                stopAnimation()
            }
    }
    
    func handleMoodChange(from oldFrames: [String], to newFrames: [String]) {
        stopAnimation()
        self.onAnimationComplete = nil
        let isAtRestingFrame = (currentFrameIndex == 0)
        guard isAnimating else {
            self.framesToPlay = newFrames
            self.currentFrameIndex = 0
            return
        }
        let isHappyToAngry = oldFrames.first?.contains("teacher_happy") ?? false && newFrames.first?.contains("teacher_angry") ?? false
        let isAngryToHappy = oldFrames.first?.contains("teacher_angry") ?? false && newFrames.first?.contains("teacher_happy") ?? false
//        let isFocusToSleep = oldFrames.first?.contains("student_focus") ?? false && newFrames.first?.contains("student_sleep") ?? false
//        let isSleepToFocus = oldFrames.first?.contains("student_sleep") ?? false && newFrames.first?.contains("student_focus") ?? false
        
        if (isAngryToHappy) && !isAtRestingFrame {
            self.framesToPlay = oldFrames.reversed()
            self.currentFrameIndex = 0
            self.onAnimationComplete = {
                self.framesToPlay = newFrames
                self.currentFrameIndex = 0
                self.startAnimation()
            }
            self.startAnimation()
        } else if (isHappyToAngry) && !isAtRestingFrame {
            self.framesToPlay = oldFrames.reversed()
            self.currentFrameIndex = 0
            self.onAnimationComplete = {
                self.framesToPlay = newFrames
                self.currentFrameIndex = 0
                self.startAnimation()
            }
            self.startAnimation()
        } else {
            self.framesToPlay = newFrames
            self.currentFrameIndex = 0
            self.startAnimation()
        }
    }
    
    func startAnimation() {
        stopAnimation()
        guard !framesToPlay.isEmpty, currentFrameIndex < framesToPlay.count - 1 else { return }
        timerSubscription = Timer.publish(every: animationInterval, on: .main, in: .common)
            .autoconnect()
            .sink { _ in
                if self.currentFrameIndex < self.framesToPlay.count - 1 {
                    self.currentFrameIndex += 1
                } else {
                    self.stopAnimation()
                    if let completion = self.onAnimationComplete {
                        self.onAnimationComplete = nil
                        completion()
                    }
                }
            }
    }
    
    func stopAnimation() {
        timerSubscription?.cancel()
        timerSubscription = nil
    }
}
