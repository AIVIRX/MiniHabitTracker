import Foundation
import UIKit
import CoreHaptics

final class HapticManager {
    static let shared = HapticManager()
    
    private var hapticsAvailable: Bool = false
    private var engine: CHHapticEngine?
    private var isEngineStarted: Bool = false
    private var lastWaveBounceTime: CFTimeInterval = 0
    
    private init() {
        hapticsAvailable = CHHapticEngine.capabilitiesForHardware().supportsHaptics
        if hapticsAvailable {
            createEngine()
        }
    }
    
    // MARK: - Public API
    func prepare() {
        guard hapticsAvailable else { return }
        startEngineIfNeeded()
    }
    
    func selectionChanged() {
        UISelectionFeedbackGenerator().selectionChanged()
    }
    
    func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
    }
    
    func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        UINotificationFeedbackGenerator().notificationOccurred(type)
    }
    
    // Super-unique haptic for the calendar wave bounce
    // Pattern: quick compress tap -> stronger release burst -> short tail
    func playWaveBounce() {
        // Throttle spam so rapid taps don't saturate the haptics engine.
        let now = CACurrentMediaTime()
        if now - lastWaveBounceTime < 0.09 { return }
        lastWaveBounceTime = now

        guard hapticsAvailable else {
            // Graceful fallback if Core Haptics unavailable
            let generator = UIImpactFeedbackGenerator(style: .rigid)
            generator.impactOccurred(intensity: 1.0)
            return
        }
        startEngineIfNeeded()
        do {
            let events: [CHHapticEvent] = [
                // Initial compress (shrink): a soft, sharp transient
                CHHapticEvent(eventType: .hapticTransient,
                              parameters: [
                                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.35),
                                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.8)
                              ],
                              relativeTime: 0.0),
                
                // Release (grow past): a stronger, slightly rounder transient
                CHHapticEvent(eventType: .hapticTransient,
                              parameters: [
                                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.9),
                                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.55)
                              ],
                              relativeTime: 0.065),
                
                // Short tail that eases out (continuous with ramp-down)
                CHHapticEvent(eventType: .hapticContinuous,
                              parameters: [
                                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.35),
                                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.35)
                              ],
                              relativeTime: 0.11,
                              duration: 0.08)
            ]
            
            // Subtle audio for richer feel (if device supports it)
            let parameters: [CHHapticParameterCurve] = [
                CHHapticParameterCurve(
                    parameterID: .hapticIntensityControl,
                    controlPoints: [
                        CHHapticParameterCurve.ControlPoint(relativeTime: 0.11, value: 0.35),
                        CHHapticParameterCurve.ControlPoint(relativeTime: 0.19, value: 0.0)
                    ],
                    relativeTime: 0.0
                )
            ]
            
            let pattern = try CHHapticPattern(events: events, parameterCurves: parameters)
            let player = try engine?.makeAdvancedPlayer(with: pattern)
            try player?.start(atTime: 0)
        } catch {
            // Fallback on any failure
            let generator = UIImpactFeedbackGenerator(style: .rigid)
            generator.impactOccurred()
        }
    }
    
    // MARK: - Engine lifecycle
    private func createEngine() {
        do {
            engine = try CHHapticEngine()
            engine?.isAutoShutdownEnabled = true
            engine?.stoppedHandler = { [weak self] reason in
                self?.isEngineStarted = false
            }
            engine?.resetHandler = { [weak self] in
                self?.isEngineStarted = false
                self?.startEngineIfNeeded()
            }
        } catch {
            hapticsAvailable = false
            engine = nil
        }
    }
    
    private func startEngineIfNeeded() {
        guard hapticsAvailable, let engine else { return }
        guard !isEngineStarted else { return }
        do {
            try engine.start()
            isEngineStarted = true
        } catch {
            isEngineStarted = false
        }
    }
}

