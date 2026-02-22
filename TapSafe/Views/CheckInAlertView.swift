//
//  CheckInAlertView.swift
//  TapSafe
//
//  Enhanced check-in alert with ringer, flash, and Face ID authentication
//  Displays when HRM is deactivated; requires "OK" button tap + Face ID/Passcode auth
//  Escalates to emergency contact after 1 minute without successful auth
//

import AVFoundation
import LocalAuthentication
import SwiftUI
import UIKit

struct CheckInAlertView: View {
    @ObservedObject var safetyManager: SafetyManager
    
    @State private var isAuthenticating = false
    @State private var authenticationError: String?
    @State private var remainingTime: Int = 60
    @State private var timer: Timer?
    @State private var flashOpacity: Double = 1.0
    @State private var flashTimer: Timer?
    @State private var ringerTimer: Timer?
    @State private var okTapped: Bool = false
    
    var body: some View {
        ZStack {
            // Flashing background
            Color.red
                .opacity(flashOpacity)
                .ignoresSafeArea()
                .onAppear {
                    startFlashing()
                }
            
            if !okTapped {
                // Initial alert asking user to tap OK
                VStack(spacing: 24) {
                    // Large warning icon
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.yellow)
                        .scaleEffect(1.0)
                        .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: true)
                    
                    VStack(spacing: 12) {
                        Text("CHECK IN REQUIRED")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text("Heart rate monitor not detected")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                    }
                    
                    // Countdown timer
                    HStack(spacing: 12) {
                        Image(systemName: "timer")
                            .foregroundColor(.white)
                        Text("Respond in: \(remainingTime)s")
                            .font(.system(size: 18, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                    }
                    .padding(12)
                    .background(Color.black.opacity(0.5))
                    .cornerRadius(8)
                    
                    Spacer()
                    
                    // OK button
                    Button(action: {
                        okTapped = true
                        playAudioFeedback()
                    }) {
                        Text("OK")
                            .font(.system(size: 24, weight: .bold))
                            .frame(maxWidth: .infinity)
                            .padding(20)
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(16)
                    }
                    .padding(24)
                }
                .padding(24)
            } else {
                // Authentication phase
                VStack(spacing: 24) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.white)
                    
                    VStack(spacing: 12) {
                        Text("AUTHENTICATE")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text("Confirm with Face ID or Passcode")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                    }
                    
                    // Countdown timer
                    HStack(spacing: 12) {
                        Image(systemName: "timer")
                            .foregroundColor(.white)
                        Text("Auth timeout in: \(remainingTime)s")
                            .font(.system(size: 16, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                    }
                    .padding(12)
                    .background(Color.black.opacity(0.5))
                    .cornerRadius(8)
                    
                    if let error = authenticationError {
                        HStack(spacing: 8) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.yellow)
                            Text(error)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.yellow)
                        }
                        .padding(12)
                        .background(Color.black.opacity(0.6))
                        .cornerRadius(8)
                    }
                    
                    Spacer()
                    
                    // Authenticate button
                    Button(action: authenticate) {
                        HStack(spacing: 12) {
                            if isAuthenticating {
                                ProgressView()
                                    .progressViewStyle(.circular)
                                    .tint(.white)
                            } else {
                                Image(systemName: "faceid")
                                    .font(.system(size: 18, weight: .semibold))
                            }
                            
                            Text(isAuthenticating ? "Authenticating..." : "Authenticate")
                                .font(.system(size: 18, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(16)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(isAuthenticating)
                    .padding(24)
                }
                .padding(24)
                .onAppear {
                    authenticate()  // Auto-attempt authentication
                }
            }
        }
        .onAppear {
            startRinger()
            startTimer()
        }
        .onDisappear {
            stopTimer()
            stopRinger()
            stopFlashing()
        }
    }
    
    // MARK: - Authentication
    
    private func authenticate() {
        let context = LAContext()
        var error: NSError?
        
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) ||
              context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            authenticationError = error?.localizedDescription ?? "Authentication not available"
            print("❌ [CheckInAlert] Authentication not available: \(error?.localizedDescription ?? "Unknown")")
            return
        }
        
        isAuthenticating = true
        authenticationError = nil
        
        context.evaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            localizedReason: "Confirm you're safe - authenticate to reset timer"
        ) { [self] success, error in
            DispatchQueue.main.async {
                isAuthenticating = false
                
                if success {
                    print("✅ [CheckInAlert] Authentication successful")
                    stopRinger()
                    stopFlashing()
                    safetyManager.completeCheckIn()  // Resets 5-minute timer
                } else if let error = error {
                    let nsError = error as NSError
                    switch nsError.code {
                    case LAError.authenticationFailed.rawValue:
                        authenticationError = "Authentication failed. Try again."
                    case LAError.userCancel.rawValue:
                        authenticationError = "Try again to confirm you're safe."
                    case LAError.userFallback.rawValue:
                        print("📍 [CheckInAlert] User requested fallback")
                    default:
                        authenticationError = "Error: \(error.localizedDescription)"
                    }
                    print("❌ [CheckInAlert] Authentication failed: \(error.localizedDescription)")
                }
            }
        }
    }
    
    // MARK: - Alert Effects
    
    private func startRinger() {
        // Setup audio session for loud ringer
        let audioSession = AVAudioSession.sharedInstance()
        try? audioSession.setCategory(.playback, mode: .default, options: [.duckOthers, .defaultToSpeaker])
        try? audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        
        // Start ringer timer - play sound every 0.8 seconds
        ringerTimer = Timer.scheduledTimer(withTimeInterval: 0.8, repeats: true) { [self] _ in
            playAlarmSound()
        }
        
        // Play first sound immediately
        playAlarmSound()
    }
    
    private func stopRinger() {
        ringerTimer?.invalidate()
        ringerTimer = nil
        
        // Deactivate audio session
        let audioSession = AVAudioSession.sharedInstance()
        try? audioSession.setActive(false, options: .notifyOthersOnDeactivation)
    }
    
    private func playAlarmSound() {
        // Use high-priority alarm sound (1005 = Alarm)
        let soundID: SystemSoundID = 1005
        AudioServicesPlayAlertSound(soundID)
    }
    
    private func playAudioFeedback() {
        // Play "OK" confirmation sound (1057 = Chime Up)
        AudioServicesPlaySystemSound(1057)
    }
    
    private func startFlashing() {
        // Clear any existing timer
        flashTimer?.invalidate()
        
        // Start flashing every 300ms
        flashTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { [self] _ in
            withAnimation(.easeInOut(duration: 0.15)) {
                flashOpacity = (flashOpacity == 1.0) ? 0.2 : 1.0
            }
        }
    }
    
    private func stopFlashing() {
        flashTimer?.invalidate()
        flashTimer = nil
    }
    
    // MARK: - Timer
    
    private func startTimer() {
        remainingTime = 60
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [self] _ in
            remainingTime -= 1
            
            if remainingTime <= 0 {
                stopTimer()
                stopRinger()
                stopFlashing()
                
                // Escalate to emergency contact
                print("⚠️ [CheckInAlert] No response after 60 seconds - escalating to emergency contact")
                safetyManager.escalateToEmergencyContact(location: nil)
            }
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}

#Preview {
    CheckInAlertView(safetyManager: SafetyManager(store: SafetyStore()))
        .preferredColorScheme(.dark)
}
