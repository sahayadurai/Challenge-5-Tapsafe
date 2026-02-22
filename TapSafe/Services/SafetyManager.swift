//
//  SafetyManager.swift
//  TapSafe
//
//  Coordinates location (stationary detection), Watch heart rate, check-in, and emergency escalation.
//

import Combine
import CoreLocation
import Foundation
import MessageUI
import SwiftUI
import UIKit
import UserNotifications
import CallKit

final class SafetyManager: ObservableObject {
    @Published var statusMessage: String = "Starting your safe walk..."
    @Published var isWalkActive: Bool = false
    @Published var currentHeartRate: Double?
    @Published var showCheckInAlert: Bool = false          // For CheckInAuthenticationView (original)
    @Published var showEmergencyCheckInAlert: Bool = false // For CheckInAlertView (new ringer/flash version)
    @Published var failedCheckIns: Int = 0
    
    private let locationManager = LocationManager()
    private let watchManager = WatchConnectivityManager.shared
    private let notificationService = SafetyNotificationService.shared
    private let store: SafetyStore
    
    /// Timer for periodic check-ins when watch is undetected
    private var checkInTimer: Timer?
    
    /// Whether watch connectivity has been detected during this walk
    private var watchDetected: Bool = false
    
    init(store: SafetyStore) {
        self.store = store
        setupCallbacks()
    }
    
    private func setupCallbacks() {
        locationManager.onStationaryTooLong = { [weak self] in
            self?.triggerCheckIn(reason: "You've been stationary for over 2 minutes outside your destination.")
        }
        watchManager.onHeartRateSpike = { [weak self] bpm in
            self?.watchDetected = true
            if bpm == 0 {
                self?.triggerCheckIn(reason: "Heart rate could not be detected.")
            } else {
                self?.triggerCheckIn(reason: "Heart rate spike detected (\(Int(bpm)) bpm).")
            }
        }
        watchManager.onHeartRateUpdate = { [weak self] bpm in
            self?.watchDetected = true
            DispatchQueue.main.async {
                self?.currentHeartRate = bpm
            }
        }
        notificationService.onEscalateToContact = { [weak self] _, location in
            self?.escalateToEmergencyContact(location: location)
        }
    }
    
    func startWalk() {
        // Reset watch detection flag at start of walk
        watchDetected = false
        failedCheckIns = 0
        showCheckInAlert = false
        stopPeriodicCheckInTimer()  // Clear any existing timer
        
        notificationService.resetCheckInState()
        notificationService.requestAuthorization { [weak self] granted, _ in
            guard let self = self else { return }
            if !granted {
                self.statusMessage = "Enable notifications for check-in alerts."
            }
            self.locationManager.requestAlwaysAuthorization()
            self.locationManager.startUpdatingLocation(destination: self.store.destination)
            self.watchManager.activate()
            // Send the current heart rate threshold to the Watch
            self.watchManager.sendHeartRateThreshold(self.store.heartRateThreshold)
            self.isWalkActive = true
            self.statusMessage = "Monitoring your route and heart rate..."
            
            // Schedule check for watch availability after 45 seconds
            // If watchDetected is still false, assume watch is unavailable and start periodic check-ins
            DispatchQueue.main.asyncAfter(deadline: .now() + 45.0) { [weak self] in
                guard let self = self, self.isWalkActive else { return }
                if !self.watchDetected {
                    print("⚠️ [SafetyManager] Watch not detected after 45 seconds - starting fallback check-in timer")
                    self.statusMessage = "⏱️ Watch not detected. Starting periodic check-ins..."
                    self.startPeriodicCheckInTimer()
                }
            }
        }
    }
    
    func endWalk() {
        locationManager.stopUpdatingLocation()
        notificationService.resetCheckInState()
        stopPeriodicCheckInTimer()  // Stop check-in timer if running
        isWalkActive = false
        statusMessage = "Walk ended."
    }
    
    private func triggerCheckIn(reason: String) {
        notificationService.lastKnownLocation = locationManager.lastLocation
        notificationService.sendCheckIn(reason: reason)
        statusMessage = "Check-in sent. Tap \"I'm Safe\" when you see the alert."
    }
    
    func userRespondedSafe() {
        notificationService.markRespondedSafe()
        statusMessage = "You’re safe. We’ll keep monitoring."
    }
    
    func escalateToEmergencyContact(location: CLLocation?) {
        notificationService.lastKnownLocation = location ?? locationManager.lastLocation
        let loc = notificationService.lastKnownLocation
        let contact = store.emergencyContact
        let body = SafetyNotificationService.emergencyMessageBody(location: loc)
        
        statusMessage = "No response — alerting emergency contact."
        
        // Notify the user that we're escalating (standard notification; use Critical Alert if entitlement approved).
        let content = UNMutableNotificationContent()
        content.title = "TapSafe: Contacting Emergency Contact"
        content.body = "You didn’t respond. We’re sharing your location with \(contact?.name ?? "your emergency contact")."
        content.sound = .default
        if #available(iOS 15.0, *) {
            content.interruptionLevel = .timeSensitive
        }
        let request = UNNotificationRequest(identifier: "tapsafe-escalation-\(UUID().uuidString)", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
        
        // Attempt to make automatic call using tel: URL scheme
        guard let c = contact else { return }
        let number = c.phoneNumber.filter { $0.isNumber }
        
        // First, try to make a call via tel: URL scheme (opens Phone app)
        makeAutomaticCall(to: number, contact: c.name)
        
        // Copy message to clipboard for fallback
        UIPasteboard.general.string = body
        
        // Show message composer as fallback
        if MFMessageComposeViewController.canSendText(), let topVC = topViewController() {
            let composer = MFMessageComposeViewController()
            composer.recipients = [number]
            composer.body = body
            composer.messageComposeDelegate = composerDelegate
            composerDelegate.retainedComposer = composer
            topVC.present(composer, animated: true)
        } else if let url = URL(string: "sms:\(number)") {
            DispatchQueue.main.async {
                UIApplication.shared.open(url)
            }
        }
    }
    
    /// Attempt to make an automatic emergency call
    private func makeAutomaticCall(to phoneNumber: String, contact: String) {
        // Initiate call through tel: URL scheme (opens Phone app)
        let formattedNumber = phoneNumber.filter { $0.isNumber }
        guard !formattedNumber.isEmpty, let url = URL(string: "tel://\(formattedNumber)") else {
            return
        }
        
        // Schedule the call after a brief delay to allow UI updates
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            UIApplication.shared.open(url) { success in
                if success {
                    DispatchQueue.main.async {
                        self.statusMessage = "Calling \(contact) - \(phoneNumber)"
                    }
                }
            }
        }
    }
    
    private func topViewController() -> UIViewController? {
        let keyWindow = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }
        var vc = keyWindow?.rootViewController
        while let presented = vc?.presentedViewController { vc = presented }
        return vc
    }
    
    // MARK: - Periodic Check-In Timer (Fallback when watch unavailable)
    
    /// Starts periodic check-in timer that fires every `store.checkInInterval` minutes
    /// Called when watch is detected as unavailable (no heartbeat for >30 seconds after walk starts)
    private func startPeriodicCheckInTimer() {
        // Stop any existing timer
        stopPeriodicCheckInTimer()
        
        let intervalSeconds = store.checkInInterval * 60.0  // Convert minutes to seconds
        
        DispatchQueue.main.async { [weak self] in
            self?.checkInTimer = Timer.scheduledTimer(withTimeInterval: intervalSeconds, repeats: true) { [weak self] _ in
                self?.triggerPeriodicCheckIn()
            }
        }
        
        statusMessage = "⏱️ Check-in timer started: every \(Int(store.checkInInterval)) minutes"
        print("🔔 [SafetyManager] Periodic check-in timer started - interval: \(store.checkInInterval) min")
    }
    
    /// Stops the periodic check-in timer
    private func stopPeriodicCheckInTimer() {
        checkInTimer?.invalidate()
        checkInTimer = nil
        print("🔔 [SafetyManager] Periodic check-in timer stopped")
    }
    
    /// Triggered by periodic timer when watch is unavailable
    /// Shows check-in prompt with notification and vibration
    private func triggerPeriodicCheckIn() {
        print("🔔 [SafetyManager] Periodic check-in triggered - HRM deactivated")
        
        // Show the new CheckInAlertView with ringer and flash
        DispatchQueue.main.async { [weak self] in
            self?.showEmergencyCheckInAlert = true
        }
        
        // The CheckInAlertView handles its own ringer/flash and 60-second timer
        // If authentication fails after 60 seconds, CheckInAlertView calls escalateToEmergencyContact
    }
    
    /// Called when user responds to check-in successfully (passes Face ID/Passcode)
    /// Resets failed attempts and restarts timer
    func completeCheckIn() {
        print("✅ [SafetyManager] Check-in completed successfully - resetting timer")
        
        DispatchQueue.main.async { [weak self] in
            self?.showCheckInAlert = false
            self?.showEmergencyCheckInAlert = false  // Dismiss emergency alert if shown
            self?.failedCheckIns = 0  // Reset counter on successful check-in
        }
        
        // Restart the periodic timer
        startPeriodicCheckInTimer()
    }
    
    /// Called when user fails check-in authentication
    /// Increments failed attempts counter
    func failedCheckInAttempt() {
        print("❌ [SafetyManager] Check-in attempt failed - failedCheckIns: \(failedCheckIns + 1)")
        
        DispatchQueue.main.async { [weak self] in
            self?.failedCheckIns += 1
        }
    }
}

private final class MessageComposerDelegate: NSObject, MFMessageComposeViewControllerDelegate {
    var retainedComposer: MFMessageComposeViewController?
    func messageComposeViewController(_ controller: MFMessageComposeViewController, didFinishWith result: MessageComposeResult) {
        controller.dismiss(animated: true)
        retainedComposer = nil
    }
}

private let composerDelegate = MessageComposerDelegate()
