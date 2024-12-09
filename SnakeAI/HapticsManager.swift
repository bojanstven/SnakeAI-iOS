import Foundation
import CoreHaptics
import SwiftUI

class HapticsManager: ObservableObject {
    private var engine: CHHapticEngine?
    
    init() {
        prepareHaptics()
    }
    
    private func prepareHaptics() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        
        do {
            engine = try CHHapticEngine()
            
            // Restart the engine in case it stops
            engine?.resetHandler = { [weak self] in
                print("🐍 Restarting Haptic engine...")
                do {
                    try self?.engine?.start()
                } catch {
                    print("🐍 Failed to restart engine: \(error.localizedDescription)")
                }
            }
            
            // Stop handler
            engine?.stoppedHandler = { reason in
                print("🐍 Stop Handler: The engine stopped for reason: \(reason.rawValue)")
                self.prepareHaptics() // Try to reinitialize
            }
            
            // Start the engine and keep it running
            try engine?.start()
        } catch {
            print("🐍 There was an error creating the haptics engine: \(error.localizedDescription)")
        }
    }
    
    private func ensureEngineRunning() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        
        if engine == nil {
            prepareHaptics()
        }
        
        do {
            try engine?.start()
        } catch {
            print("🐍 Failed to start engine: \(error.localizedDescription)")
            prepareHaptics() // Try to reinitialize if start fails
        }
    }
    
    func foodEatenHaptic() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        
        ensureEngineRunning()
        
        do {
            let pattern = try foodPattern()
            let player = try engine?.makePlayer(with: pattern)
            try player?.start(atTime: CHHapticTimeImmediate)
        } catch {
            print("🐍 Failed to play food haptic pattern: \(error.localizedDescription)")
            prepareHaptics() // Try to recover
        }
    }
    
    func gameOverHaptic() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        
        ensureEngineRunning()
        
        do {
            let pattern = try gameOverPattern()
            let player = try engine?.makePlayer(with: pattern)
            try player?.start(atTime: CHHapticTimeImmediate)
        } catch {
            print("🐍 Failed to play game over haptic pattern: \(error.localizedDescription)")
            prepareHaptics() // Try to recover
        }
    }
    
    func toggleHaptic() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        
        ensureEngineRunning()
        
        do {
            let pattern = try togglePattern()
            let player = try engine?.makePlayer(with: pattern)
            try player?.start(atTime: CHHapticTimeImmediate)
        } catch {
            print("🐍 Failed to play toggle haptic pattern: \(error.localizedDescription)")
            prepareHaptics() // Try to recover
        }
    }
    
    private func foodPattern() throws -> CHHapticPattern {
        // Initial "pop" sensation
        let sharpPop = CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.7),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.9)
            ],
            relativeTime: 0
        )
        
        // Quick follow-up "sparkle" sensation
        let sparkle1 = CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.5),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.8)
            ],
            relativeTime: 0.05
        )
        
        let sparkle2 = CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.3),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.7)
            ],
            relativeTime: 0.1
        )
        
        // Add a subtle continuous undertone
        let undertone = CHHapticEvent(
            eventType: .hapticContinuous,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.3),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.3)
            ],
            relativeTime: 0,
            duration: 0.15
        )
        
        return try CHHapticPattern(events: [sharpPop, sparkle1, sparkle2, undertone], parameters: [])
    }
    
    private func gameOverPattern() throws -> CHHapticPattern {
        var events: [CHHapticEvent] = []
        
        // Initial strong impact
        let impact = CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.8)
            ],
            relativeTime: 0
        )
        events.append(impact)
        
        // Rumble buildup
        let rumble = CHHapticEvent(
            eventType: .hapticContinuous,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.8),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.3)
            ],
            relativeTime: 0.1,
            duration: 0.4
        )
        events.append(rumble)
        
        // Add three decreasing "aftershock" impacts
        for i in 0..<3 {
            let intensity = Float(0.7 - (Float(i) * 0.2))
            let aftershock = CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5)
                ],
                relativeTime: 0.2 + Double(i) * 0.1
            )
            events.append(aftershock)
        }
        
        // Final fade-out rumble
        let fadeOut = CHHapticEvent(
            eventType: .hapticContinuous,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.3),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.2)
            ],
            relativeTime: 0.5,
            duration: 0.3
        )
        events.append(fadeOut)
        
        return try CHHapticPattern(events: events, parameters: [])
    }
    
    private func togglePattern() throws -> CHHapticPattern {
        // Quick, crisp toggle sensation
        let toggleClick = CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.5),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.9)
            ],
            relativeTime: 0
        )
        
        // Subtle follow-up tap
        let followupTap = CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.3),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.7)
            ],
            relativeTime: 0.05
        )
        
        return try CHHapticPattern(events: [toggleClick, followupTap], parameters: [])
    }
}
