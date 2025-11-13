//
//  RootView.swift
//  PublicSpeakingAPP
//
//  Created by Jordan on 23/10/25.
//

import SwiftUI
import WhisperKit

enum AppFlowStep {
    case loading
    case onboarding
    case home
}

struct RootView: View {
    
    init() {
        if ProcessInfo.processInfo.arguments.contains("-ResetOnboarding") {
            UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")
            _hasCompletedOnboarding = AppStorage(wrappedValue: false, "hasCompletedOnboarding")
        }
    }
    
    @EnvironmentObject private var whisperKitVM: SpeechTranscriberViewModel
    
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = false
    
    @State private var currentStep: AppFlowStep = .loading
    
    var body: some View {
        ZStack {
            switch currentStep {
            
            case .loading:
                LoadingView()
                    .transition(.opacity)
                
            case .onboarding:
                OnboardingView(
                    onStartTapped: {
                        self.hasCompletedOnboarding = true
                        withAnimation {
                            self.currentStep = .home
                        }
                    }
                )
                .transition(.opacity)
                
            case .home:
                NavigationStack {
                    HomeView()
                }
                .transition(.opacity)
            }
        }
        .onReceive(whisperKitVM.$modelState) { newState in
            if newState == .loaded && self.currentStep == .loading {
                if hasCompletedOnboarding {
                    withAnimation(.easeInOut(duration: 0.5)) {
                        self.currentStep = .home
                    }
                } else {
                    withAnimation(.easeInOut(duration: 0.5)) {
                        self.currentStep = .onboarding
                    }
                }
            }
        }
    }
}
