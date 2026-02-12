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

final class SafetyManager: ObservableObject {
    @Published var statusMessage: String = "Starting your safe walk..."
    @Published var isWalkActive: Bool = false
    
    private let locationManager = LocationManager()
    private let watchManager = WatchConnectivityManager.shared
    private let notificationService = SafetyNotificationService.shared
    private let store: SafetyStore
    
    init(store: SafetyStore) {
        self.store = store
        setupCallbacks()
    }
    
    private func setupCallbacks() {
        locationManager.onStationaryTooLong = { [weak self] in
            self?.triggerCheckIn(reason: "You’ve been stationary for over 2 minutes outside your destination.")
        }
        watchManager.onHeartRateSpike = { [weak self] bpm in
            self?.triggerCheckIn(reason: "Heart rate spike detected (\(Int(bpm)) bpm).")
        }
        notificationService.onEscalateToContact = { [weak self] _, location in
            self?.escalateToEmergencyContact(location: location)
        }
    }
    
    func startWalk() {
        notificationService.resetCheckInState()
        notificationService.requestAuthorization { [weak self] granted, _ in
            guard let self = self else { return }
            if !granted {
                self.statusMessage = "Enable notifications for check-in alerts."
            }
            self.locationManager.requestAlwaysAuthorization()
            self.locationManager.startUpdatingLocation(destination: self.store.destination)
            self.watchManager.activate()
            self.isWalkActive = true
            self.statusMessage = "Monitoring your route and heart rate..."
        }
    }
    
    func endWalk() {
        locationManager.stopUpdatingLocation()
        notificationService.resetCheckInState()
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
    
    private func escalateToEmergencyContact(location: CLLocation?) {
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
        
        // Open message composer with body (or sms: and copy body to clipboard).
        guard let c = contact else { return }
        let number = c.phoneNumber.filter { $0.isNumber }
        UIPasteboard.general.string = body
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
    
    private func topViewController() -> UIViewController? {
        let keyWindow = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }
        var vc = keyWindow?.rootViewController
        while let presented = vc?.presentedViewController { vc = presented }
        return vc
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
