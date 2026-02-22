//
//  WatchConnectivityManager.swift
//  TapSafe
//
//  Receives heart rate spike events from Apple Watch via WatchConnectivity.
//

import Combine
import Foundation
import SwiftUI
import WatchConnectivity

/// Message keys used between Watch and iPhone.
enum WatchMessageKey {
    static let heartRateSpike = "heartRateSpike"
    static let heartRateBPM = "heartRateBPM"
    static let timestamp = "timestamp"
    static let heartRateNotDetected = "heartRateNotDetected"
    static let heartRateThreshold = "heartRateThreshold"
    static let heartRateUpdate = "heartRateUpdate"
}

final class WatchConnectivityManager: NSObject, ObservableObject {
    static let shared = WatchConnectivityManager()
    
    @Published private(set) var isReachable: Bool = false
    @Published private(set) var currentHeartRate: Double?
    
    /// Called when Watch reports a heart rate spike; trigger check-in from app.
    var onHeartRateSpike: ((Double) -> Void)?
    
    /// Called with real-time heart rate readings for UI display
    var onHeartRateUpdate: ((Double) -> Void)?
    
    private override init() {
        super.init()
    }
    
    func activate() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }
    
    /// Send heart rate threshold to Watch
    func sendHeartRateThreshold(_ threshold: Double) {
        guard WCSession.default.activationState == .activated && WCSession.default.isReachable else { return }
        let message: [String: Any] = [
            WatchMessageKey.heartRateThreshold: threshold
        ]
        WCSession.default.sendMessage(message, replyHandler: nil) { _ in }
    }
}

extension WatchConnectivityManager: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        let stateString = activationState == .activated ? "✅ ACTIVATED" : "⚠️ INACTIVE"
        print("🔗 [iPhone] WCSession activation complete: \(stateString)")
        if let error = error {
            print("❌ [iPhone] WCSession error: \(error.localizedDescription)")
        }
        DispatchQueue.main.async {
            self.isReachable = session.isReachable
        }
    }
    
    #if os(iOS)
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
    #endif
    
    func sessionReachabilityDidChange(_ session: WCSession) {
        let reachable = session.isReachable ? "✅ REACHABLE" : "❌ NOT REACHABLE"
        print("🔗 [iPhone] Watch reachability changed: \(reachable)")
        DispatchQueue.main.async {
            self.isReachable = session.isReachable
        }
    }
    
    /// Receive message from Watch (e.g. heart rate spike or real-time update).
    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        print("📥 [iPhone] Received message from Watch: \(message.keys.joined(separator: ", "))")
        if let _ = message[WatchMessageKey.heartRateUpdate] as? Bool,
           let bpm = message[WatchMessageKey.heartRateBPM] as? Double {
            // Real-time heart rate update for UI display
            print("📊 [iPhone] Real-time heart rate update: \(Int(bpm)) BPM")
            DispatchQueue.main.async {
                self.currentHeartRate = bpm
                self.onHeartRateUpdate?(bpm)
            }
        } else if let _ = message[WatchMessageKey.heartRateSpike] as? Bool,
           let bpm = message[WatchMessageKey.heartRateBPM] as? Double {
            print("⚠️ [iPhone] Heart rate spike detected: \(Int(bpm)) BPM")
            DispatchQueue.main.async {
                self.currentHeartRate = bpm
                self.onHeartRateUpdate?(bpm)
                self.onHeartRateSpike?(bpm)
            }
        } else if let _ = message[WatchMessageKey.heartRateNotDetected] as? Bool {
            print("❌ [iPhone] Heart rate not detected")
            DispatchQueue.main.async {
                self.currentHeartRate = nil
                self.onHeartRateSpike?(0) // Send 0 to trigger check-in for not detected
            }
        }
    }
    
    /// Optional: receive message with reply (Watch may use this for reliability).
    func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        print("📥 [iPhone] Received message with reply: \(message.keys.joined(separator: ", "))")
        if let _ = message[WatchMessageKey.heartRateUpdate] as? Bool,
           let bpm = message[WatchMessageKey.heartRateBPM] as? Double {
            // Real-time heart rate update for UI display
            print("📊 [iPhone] Real-time heart rate update (with reply): \(Int(bpm)) BPM")
            DispatchQueue.main.async {
                self.currentHeartRate = bpm
                self.onHeartRateUpdate?(bpm)
            }
            replyHandler(["received": true])
        } else if let _ = message[WatchMessageKey.heartRateSpike] as? Bool,
           let bpm = message[WatchMessageKey.heartRateBPM] as? Double {
            print("⚠️ [iPhone] Heart rate spike detected (with reply): \(Int(bpm)) BPM")
            DispatchQueue.main.async {
                self.currentHeartRate = bpm
                self.onHeartRateUpdate?(bpm)
                self.onHeartRateSpike?(bpm)
            }
            replyHandler(["received": true])
        } else if let _ = message[WatchMessageKey.heartRateNotDetected] as? Bool {
            print("❌ [iPhone] Heart rate not detected (with reply)")
            DispatchQueue.main.async {
                self.currentHeartRate = nil
                self.onHeartRateSpike?(0) // Send 0 to trigger check-in for not detected
            }
            replyHandler(["received": true])
        } else {
            replyHandler(["received": false])
        }
    }
}
