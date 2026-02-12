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
}

final class WatchConnectivityManager: NSObject, ObservableObject {
    static let shared = WatchConnectivityManager()
    
    @Published private(set) var isReachable: Bool = false
    
    /// Called when Watch reports a heart rate spike; trigger check-in from app.
    var onHeartRateSpike: ((Double) -> Void)?
    
    private override init() {
        super.init()
    }
    
    func activate() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }
}

extension WatchConnectivityManager: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
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
        DispatchQueue.main.async {
            self.isReachable = session.isReachable
        }
    }
    
    /// Receive message from Watch (e.g. heart rate spike).
    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        if let _ = message[WatchMessageKey.heartRateSpike] as? Bool,
           let bpm = message[WatchMessageKey.heartRateBPM] as? Double {
            DispatchQueue.main.async {
                self.onHeartRateSpike?(bpm)
            }
        }
    }
    
    /// Optional: receive message with reply (Watch may use this for reliability).
    func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        if let _ = message[WatchMessageKey.heartRateSpike] as? Bool,
           let bpm = message[WatchMessageKey.heartRateBPM] as? Double {
            DispatchQueue.main.async {
                self.onHeartRateSpike?(bpm)
            }
            replyHandler(["received": true])
        } else {
            replyHandler(["received": false])
        }
    }
}
