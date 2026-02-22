//
//  CheckInAuthenticationView.swift
//  TapSafe
//
//  Authenticates user with Face ID or Passcode to confirm they're safe
//

import LocalAuthentication
import SwiftUI

struct CheckInAuthenticationView: View {
    @ObservedObject var safetyManager: SafetyManager
    
    @State private var isAuthenticating = false
    @State private var authenticationError: String?
    @State private var remainingTime: Int = 60
    @State private var timer: Timer?
    
    var body: some View {
        ZStack {
            // Dimmed background
            Color.black.opacity(0.5)
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 56))
                        .foregroundColor(.green)
                    
                    Text("Confirm You're Safe")
                        .font(.system(size: 24, weight: .bold))
                        .multilineTextAlignment(.center)
                    
                    Text("Authenticate to confirm your location")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
                
                // Timer countdown
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: "timer")
                            .foregroundColor(.orange)
                        Text("Next check-in in:")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.gray)
                        Spacer()
                        Text("\(remainingTime)s")
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundColor(.orange)
                    }
                    
                    ProgressView(value: Double(remainingTime) / 60.0)
                        .tint(.orange)
                }
                
                // Failed attempts counter (if applicable)
                if safetyManager.failedCheckIns > 0 {
                    HStack {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundColor(.red)
                        Text("Failed attempts: \(safetyManager.failedCheckIns)")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.red)
                        if safetyManager.failedCheckIns >= 1 {
                            Spacer()
                            Text("Next: Emergency Contact")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.red)
                        }
                    }
                    .padding(12)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
                }
                
                // Authenticate button
                Button(action: authenticate) {
                    HStack(spacing: 12) {
                        if isAuthenticating {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .tint(.white)
                        } else {
                            Image(systemName: "faceid")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        
                        Text(isAuthenticating ? "Authenticating..." : "Authenticate")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(16)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(isAuthenticating)
                
                // Error message
                if let error = authenticationError {
                    HStack(spacing: 8) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.red)
                        Text(error)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.red)
                    }
                    .padding(12)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
                }
                
                // Passcode fallback
                Button(action: {}) {
                    Text("Can't use Face ID? Use Passcode")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.blue)
                }
                
                Spacer()
                
                Text("Your emergency contact will be notified if you don't respond")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
            }
            .padding(24)
            .background(Color(UIColor.systemBackground))
            .cornerRadius(16)
            .padding(20)
        }
        .onAppear {
            startTimer()
            authenticate()  // Auto-attempt authentication on appear
        }
        .onDisappear {
            stopTimer()
        }
    }
    
    // MARK: - Authentication
    
    private func authenticate() {
        let context = LAContext()
        var error: NSError?
        
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) ||
              context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            authenticationError = error?.localizedDescription ?? "Authentication not available"
            print("❌ [CheckInAuth] Authentication not available: \(error?.localizedDescription ?? "Unknown")")
            return
        }
        
        isAuthenticating = true
        authenticationError = nil
        
        context.evaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            localizedReason: "Confirm you're safe and your location is secure"
        ) { [self] success, error in
            DispatchQueue.main.async {
                isAuthenticating = false
                
                if success {
                    print("✅ [CheckInAuth] Authentication successful")
                    stopTimer()
                    safetyManager.completeCheckIn()
                } else if let error = error {
                    let nsError = error as NSError
                    // Handle specific error codes
                    switch nsError.code {
                    case LAError.authenticationFailed.rawValue:
                        authenticationError = "Authentication failed. Try again."
                        safetyManager.failedCheckInAttempt()
                    case LAError.userCancel.rawValue:
                        authenticationError = "Authentication cancelled. Try again."
                        safetyManager.failedCheckInAttempt()
                    case LAError.userFallback.rawValue:
                        print("📍 [CheckInAuth] User requested fallback (passcode)")
                    default:
                        authenticationError = "Authentication error: \(error.localizedDescription)"
                        safetyManager.failedCheckInAttempt()
                    }
                    print("❌ [CheckInAuth] Authentication failed: \(error.localizedDescription)")
                }
            }
        }
    }
    
    // MARK: - Timer
    
    private func startTimer() {
        remainingTime = 60
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [self] _ in
            remainingTime -= 1
            if remainingTime <= 0 {
                stopTimer()
            }
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}

#Preview {
    CheckInAuthenticationView(safetyManager: SafetyManager(store: SafetyStore()))
        .preferredColorScheme(.dark)
}
