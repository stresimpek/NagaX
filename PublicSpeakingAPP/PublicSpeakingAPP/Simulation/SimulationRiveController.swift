//
//  SimulationRiveController.swift
//  PublicSpeakingAPP
//
//  Created by Regina Celine Adiwinata on 13/11/25.
//

import RiveRuntime
import SwiftUI
import Combine

final class SimulationRiveController: ObservableObject {
    let settings: PracticeSettings

    let rive = RiveViewModel(
        fileName: "simulation",
        stateMachineName: "State Machine 1",
        autoPlay: true,
        artboardName: "Simulation"
    )

    private var vmInstance: RiveDataBindingViewModel.Instance?

    private var isDistractionActive = false
    private var scheduledLoopWorkItem: DispatchWorkItem?
    private var scheduledDoorWorkItem: DispatchWorkItem?
    private var scheduledBottleWorkItem: DispatchWorkItem?

    init(settings: PracticeSettings) {
        self.settings = settings
        rive.riveModel?.enableAutoBind { [weak self] instance in
            self?.vmInstance = instance
        }
    }

    @MainActor
    func setScore(_ value: Double) {
        guard let numberProp = vmInstance?.numberProperty(fromPath: "PresentationScore") else {
            return
        }
        numberProp.value = Float(value)
    }

    func startDistractionLoop() {
        guard settings.distractionLevel > 0 else {
            print("Distraksi dinonaktifkan (Level 0).")
            return
        }
        guard !isDistractionActive else { return }

        isDistractionActive = true

        scheduleNextSmallDistraction()

        if settings.distractionLevel > 1 {
            scheduleDoorAndBottleOncePerHalf()
        }
    }

    func stopDistractionLoop() {
        isDistractionActive = false

        scheduledLoopWorkItem?.cancel()
        scheduledLoopWorkItem = nil

        scheduledDoorWorkItem?.cancel()
        scheduledDoorWorkItem = nil

        scheduledBottleWorkItem?.cancel()
        scheduledBottleWorkItem = nil
    }
    
    func triggerBoredomBar(value: Bool) {
        guard let vm = vmInstance,
              let boredom = vm.booleanProperty(fromPath: "EngagementBar OFF") else {
            return
        }

        boredom.value = value
    }
    
    func triggerDifferentiateWithoutColor(value: Bool) {
        guard let vm = vmInstance,
              let differentiateWithoutColor = vm.booleanProperty(fromPath: "Differentiate") else {
            return
        }
        
        differentiateWithoutColor.value = value
    }


    func pauseAll() {
        stopDistractionLoop()
    }
    
    func pause() {
        rive.pause()
    }

    func resumeAll() {
        rive.play()
    }

    func view() -> some View { rive.view() }
}

private extension SimulationRiveController {
    func scheduleNextSmallDistraction() {
        guard isDistractionActive else { return }
        guard let vmInstance else {
            print("VM belum siap, tunda small distraction.")
            return
        }

        guard let phoneBuzz = vmInstance.triggerProperty(fromPath: "Phone Buzz"),
              let sneeze    = vmInstance.triggerProperty(fromPath: "Sneeze") else {
            print("Trigger (Phone Buzz / Sneeze) tidak ditemukan.")
            return
        }

        let delayRange: ClosedRange<TimeInterval>
        if settings.distractionLevel == 1.0 {
            delayRange = 45.0...60.0
        } else {
            delayRange = 20.0...30.0
        }

        let randomDelay = TimeInterval.random(in: delayRange)
        print("Small distraction dalam \(String(format: "%.1f", randomDelay)) detik.")

        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            guard self.isDistractionActive else { return }

            if Bool.random() {
                phoneBuzz.trigger()
                print("Trigger: Phone Buzz")
            } else {
                sneeze.trigger()
                print("Trigger: Sneeze")
            }

            self.scheduleNextSmallDistraction()
        }

        scheduledLoopWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + randomDelay, execute: workItem)
    }

    func scheduleDoorAndBottleOncePerHalf() {
        guard let vmInstance else {
            print("VM belum siap, tunda Door/DropBottle.")
            return
        }

        guard let door       = vmInstance.triggerProperty(fromPath: "Door"),
              let dropBottle = vmInstance.triggerProperty(fromPath: "Drop Bottle") else {
            print("Trigger (Door / Drop Bottle) tidak ditemukan.")
            return
        }

        let totalDurationSec: TimeInterval
        if settings.durationMinutes > 0 {
            totalDurationSec = TimeInterval(settings.durationMinutes * 60)
        } else {
            totalDurationSec = 120
        }

        let half = totalDurationSec / 2
        
        let doorDelay = TimeInterval.random(in: 0...(max(half, 1)))
        let bottleDelay = TimeInterval.random(in: half...(max(totalDurationSec, half + 1)))

        print("Door akan dijadwalkan sekitar \(String(format: "%.1f", doorDelay)) detik dari start.")
        print("DropBottle akan dijadwalkan sekitar \(String(format: "%.1f", bottleDelay)) detik dari start.")

        let doorItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            guard self.isDistractionActive else { return }

            door.trigger()
            print("Trigger: Door (once in first half)")
        }

        let bottleItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            guard self.isDistractionActive else { return }

            dropBottle.trigger()
            print("Trigger: Drop Bottle (once in second half)")
        }

        scheduledDoorWorkItem = doorItem
        scheduledBottleWorkItem = bottleItem

        DispatchQueue.main.asyncAfter(deadline: .now() + doorDelay, execute: doorItem)
        DispatchQueue.main.asyncAfter(deadline: .now() + bottleDelay, execute: bottleItem)
    }
}
