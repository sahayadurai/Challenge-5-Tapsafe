//
//  HeartRateMonitor.swift
//  TapSafeWatch
//
//  HealthKit heart rate monitoring; sends spike to iPhone via WatchConnectivity.
//

import Foundation
import HealthKit
import WatchConnectivity

/// Message keys (must match iOS app WatchConnectivityManager).
private enum WatchMessageKey {
    static let heartRateSpike = "heartRateSpike"
    static let heartRateBPM = "heartRateBPM"
    static let timestamp = "timestamp"
    static let heartRateNotDetected = "heartRateNotDetected"
    static let heartRateThreshold = "heartRateThreshold"
    static let heartRateUpdate = "heartRateUpdate"
}

/// BPM above this is considered a "spike" for safety check-in (configurable).
private var heartRateSpikeThreshold: Double = 120

/// Time interval (seconds) after which absence of heart rate reading triggers emergency alert.
private let heartRateNotDetectedInterval: TimeInterval = 30

/// Interval for sending real-time heart rate updates to iPhone (seconds)
private let heartRateUpdateInterval: TimeInterval = 2

final class HeartRateMonitor: NSObject, ObservableObject {
    private let healthStore = HKHealthStore()
    private var anchoredQuery: HKAnchoredObjectQuery?
    
    @Published private(set) var lastHeartRate: Double?
    
    /// Timestamp of last successful heart rate reading
    private var lastHeartRateReadingTime: Date?
    
    /// Timer to monitor for no heart rate detection
    private var noHeartRateDetectionTimer: Timer?
    
    /// Timer for sending real-time heart rate updates to iPhone
    private var heartRateUpdateTimer: Timer?
    
    /// Timestamp of last update sent to iPhone
    private var lastUpdateSentTime: Date?
    
    override init() {
        super.init()
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
    }
    
    /// Call from ContentView.onAppear to start HealthKit.
    func startMonitoring() {
        requestAuthorizationAndStart()
    }
    
    /// Send heart rate spike to iPhone when above threshold.
    private func sendSpikeToPhone(bpm: Double) {
        guard WCSession.default.activationState == .activated else {
            print("❌ WCSession not activated for spike. State: \(WCSession.default.activationState.rawValue)")
            return
        }
        let message: [String: Any] = [
            WatchMessageKey.heartRateSpike: true,
            WatchMessageKey.heartRateBPM: bpm,
            WatchMessageKey.timestamp: Date().timeIntervalSince1970
        ]
        print("📤 Sending spike alert to iPhone: \(Int(bpm)) BPM")
        WCSession.default.sendMessage(message, replyHandler: nil) { error in
            print("❌ Failed to send spike: \(error.localizedDescription)")
        }
    }
    
    /// Send real-time heart rate update to iPhone (for UI display).
    private func sendHeartRateUpdate(bpm: Double) {
        guard WCSession.default.activationState == .activated else {
            print("❌ WCSession not activated for update. State: \(WCSession.default.activationState.rawValue)")
            return
        }
        let message: [String: Any] = [
            WatchMessageKey.heartRateUpdate: true,
            WatchMessageKey.heartRateBPM: bpm,
            WatchMessageKey.timestamp: Date().timeIntervalSince1970
        ]
        print("📤 Sending real-time update to iPhone: \(Int(bpm)) BPM")
        WCSession.default.sendMessage(message, replyHandler: nil) { error in
            print("❌ Failed to send update: \(error.localizedDescription)")
        }
    }
    
    /// Send alert to iPhone when heart rate is not detected.
    private func sendHeartRateNotDetectedAlert() {
        guard WCSession.default.activationState == .activated else { return }
        let message: [String: Any] = [
            WatchMessageKey.heartRateNotDetected: true,
            WatchMessageKey.timestamp: Date().timeIntervalSince1970
        ]
        WCSession.default.sendMessage(message, replyHandler: nil) { _ in }
    }
    
    /// Start monitoring for no heart rate detection and sending real-time updates.
    private func startHeartRateDetectionMonitoring() {
        noHeartRateDetectionTimer?.invalidate()
        noHeartRateDetectionTimer = Timer.scheduledTimer(withTimeInterval: heartRateNotDetectedInterval, repeats: true) { [weak self] _ in
            self?.checkHeartRateDetection()
        }
        
        // Start sending real-time heart rate updates
        startHeartRateUpdateTimer()
    }
    
    /// Start sending real-time heart rate updates to iPhone
    private func startHeartRateUpdateTimer() {
        heartRateUpdateTimer?.invalidate()
        heartRateUpdateTimer = Timer.scheduledTimer(withTimeInterval: heartRateUpdateInterval, repeats: true) { [weak self] _ in
            if let bpm = self?.lastHeartRate {
                self?.sendHeartRateUpdate(bpm: bpm)
            }
        }
    }
    
    /// Stop monitoring for no heart rate detection.
    private func stopHeartRateDetectionMonitoring() {
        noHeartRateDetectionTimer?.invalidate()
        noHeartRateDetectionTimer = nil
        heartRateUpdateTimer?.invalidate()
        heartRateUpdateTimer = nil
    }
    
    /// Check if heart rate has not been detected and alert if necessary.
    private func checkHeartRateDetection() {
        guard let lastReadingTime = lastHeartRateReadingTime else {
            sendHeartRateNotDetectedAlert()
            return
        }
        
        let timeSinceLastReading = Date().timeIntervalSince(lastReadingTime)
        if timeSinceLastReading > heartRateNotDetectedInterval {
            sendHeartRateNotDetectedAlert()
        }
    }
    
    func requestAuthorizationAndStart() {
        guard HKHealthStore.isHealthDataAvailable() else {
            print("❌ HealthKit not available on this Watch")
            return
        }
        
        guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else {
            print("❌ Could not create heart rate type")
            return
        }
        
        print("📱 Requesting HealthKit authorization for heart rate...")
        healthStore.requestAuthorization(toShare: [], read: [heartRateType]) { [weak self] success, error in
            if success {
                print("✅ HealthKit authorization granted")
            } else {
                print("❌ HealthKit authorization denied: \(error?.localizedDescription ?? "Unknown error")")
            }
            guard success, let self = self else { return }
            DispatchQueue.main.async {
                self.startHeartRateQuery()
            }
        }
    }
    
    private func startHeartRateQuery() {
        guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else { return }
        
        print("🔍 Starting heart rate query...")
        let query = HKAnchoredObjectQuery(
            type: heartRateType,
            predicate: nil,
            anchor: nil,
            limit: HKObjectQueryNoLimit
        ) { [weak self] _, samples, _, _, _ in
            print("📊 Initial query returned \(samples?.count ?? 0) samples")
            self?.processSamples(samples)
        }
        query.updateHandler = { [weak self] _, samples, _, _, _ in
            print("📊 Query update: \(samples?.count ?? 0) new samples")
            self?.processSamples(samples)
        }
        healthStore.execute(query)
        anchoredQuery = query
        startHeartRateDetectionMonitoring()
    }
}

extension HeartRateMonitor: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        let stateString = activationState == .activated ? "✅ ACTIVATED" : "⚠️ INACTIVE"
        print("🔗 WCSession activation complete: \(stateString)")
        if let error = error {
            print("❌ WCSession error: \(error.localizedDescription)")
        }
    }
    
    /// Receive heart rate threshold from iPhone
    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        if let threshold = message[WatchMessageKey.heartRateThreshold] as? Double {
            print("📥 Received new heart rate threshold: \(Int(threshold)) BPM")
            DispatchQueue.main.async {
                heartRateSpikeThreshold = threshold
            }
        }
    }
}

private extension HeartRateMonitor {
    func processSamples(_ samples: [HKSample]?) {
        guard let samples = samples as? [HKQuantitySample], !samples.isEmpty else {
            print("⚠️ No heart rate samples received")
            return
        }
        let unit = HKUnit(from: "count/min")
        for sample in samples.reversed() {
            let bpm = sample.quantity.doubleValue(for: unit)
            print("❤️ Heart rate sample received: \(Int(bpm)) BPM")
            DispatchQueue.main.async {
                self.lastHeartRate = bpm
                self.lastHeartRateReadingTime = Date()
            }
            if bpm >= heartRateSpikeThreshold {
                print("⚠️ SPIKE: \(Int(bpm)) BPM exceeds threshold \(Int(heartRateSpikeThreshold))")
                self.sendSpikeToPhone(bpm: bpm)
            }
        }
    }
}
