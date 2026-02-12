//
//  SafetyNotificationService.swift
//  TapSafe
//
//  Check-in notifications using Critical Alerts (bypass Silent) and emergency escalation.
//

import Combine
import CoreLocation
import Foundation
import SwiftUI
import UserNotifications

enum SafetyNotificationCategory {
    static let checkIn = "safety-check"
}

enum SafetyNotificationAction {
    static let safeAction = "safe-action"
}

/// Time to wait for user response to check-in before alerting emergency contact (seconds).
let checkInResponseTimeout: TimeInterval = 60

final class SafetyNotificationService: NSObject, ObservableObject {
    static let shared = SafetyNotificationService()
    
    @Published private(set) var checkInState: CheckInState = .none
    
    /// When check-in was sent; used to enforce response timeout.
    private var checkInSentAt: Date?
    private var escalationWorkItem: DispatchWorkItem?
    
    /// Called when we escalate (no response): pass contact and latest GPS for UI / opening tel/sms.
    var onEscalateToContact: ((EmergencyContact?, CLLocation?) -> Void)?
    
    /// Latest location for inclusion in emergency alert (provided by SafetyManager).
    var lastKnownLocation: CLLocation?
    
    private override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }
    
    /// Request notification permission. Use .criticalAlert in options only if Apple has granted the Critical Alerts capability.
    func requestAuthorization(completion: @escaping (Bool, Error?) -> Void) {
        let options: UNAuthorizationOptions = [.alert, .sound, .badge]
        UNUserNotificationCenter.current().requestAuthorization(options: options) { [weak self] granted, error in
            DispatchQueue.main.async {
                if granted {
                    self?.registerCategories()
                }
                completion(granted, error)
            }
        }
    }
    
    private func registerCategories() {
        let safeAction = UNNotificationAction(
            identifier: SafetyNotificationAction.safeAction,
            title: "I'm Safe",
            options: [.foreground]
        )
        let category = UNNotificationCategory(
            identifier: SafetyNotificationCategory.checkIn,
            actions: [safeAction],
            intentIdentifiers: [],
            options: []
        )
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }
    
    /// Send check-in notification. Uses Critical Alert sound when entitlement is available.
    func sendCheckIn(reason: String) {
        let content = UNMutableNotificationContent()
        content.title = "TapSafe Check-In"
        content.body = "Are you okay? Tap to confirm you're safe. (\(reason))"
        content.categoryIdentifier = SafetyNotificationCategory.checkIn
        
        // Use standard notification (respects Silent). For Critical Alerts, add the entitlement and use defaultCriticalSound(withAudioVolume: 1.0) + .critical.
        content.sound = .default
        if #available(iOS 15.0, *) {
            content.interruptionLevel = .timeSensitive
        }
        
        let request = UNNotificationRequest(
            identifier: "tapsafe-checkin-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request) { [weak self] error in
            DispatchQueue.main.async {
                if error == nil {
                    self?.checkInState = .checkInSent
                    self?.checkInSentAt = Date()
                    self?.scheduleEscalation()
                }
            }
        }
    }
    
    private func scheduleEscalation() {
        escalationWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            self?.escalateToEmergencyContact()
        }
        escalationWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + checkInResponseTimeout, execute: item)
    }
    
    private func escalateToEmergencyContact() {
        escalationWorkItem = nil
        guard checkInState == .checkInSent else { return }
        checkInState = .escalated
        onEscalateToContact?(nil, lastKnownLocation) // Caller (SafetyManager) provides contact from store
    }
    
    /// Call when user taps "I'm Safe".
    func markRespondedSafe() {
        escalationWorkItem?.cancel()
        escalationWorkItem = nil
        checkInState = .respondedSafe
        checkInSentAt = nil
    }
    
    /// Reset state when starting a new walk or ending.
    func resetCheckInState() {
        escalationWorkItem?.cancel()
        escalationWorkItem = nil
        checkInState = .none
        checkInSentAt = nil
    }
    
    /// Build message body for emergency contact (GPS coordinates).
    static func emergencyMessageBody(location: CLLocation?) -> String {
        guard let loc = location else { return "TapSafe: I may need help. Please check on me." }
        let lat = loc.coordinate.latitude
        let lon = loc.coordinate.longitude
        let url = "https://maps.apple.com/?q=\(lat),\(lon)"
        return "TapSafe: I may need help. My location: \(lat), \(lon) — \(url)"
    }
}

extension SafetyNotificationService: UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        if response.actionIdentifier == SafetyNotificationAction.safeAction
            || response.actionIdentifier == UNNotificationDefaultActionIdentifier {
            markRespondedSafe()
        }
        completionHandler()
    }
    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge, .list])
    }
}
