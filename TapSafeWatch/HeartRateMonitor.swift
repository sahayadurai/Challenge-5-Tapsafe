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
}

/// BPM above this is considered a "spike" for safety check-in (configurable).
private let heartRateSpikeThreshold: Double = 120

final class HeartRateMonitor: NSObject, ObservableObject {
    private let healthStore = HKHealthStore()
    private var anchoredQuery: HKAnchoredObjectQuery?
    
    @Published private(set) var lastHeartRate: Double?
    
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
        guard WCSession.default.activationState == .activated else { return }
        let message: [String: Any] = [
            WatchMessageKey.heartRateSpike: true,
            WatchMessageKey.heartRateBPM: bpm,
            WatchMessageKey.timestamp: Date().timeIntervalSince1970
        ]
        WCSession.default.sendMessage(message, replyHandler: nil) { _ in }
    }
    
    func requestAuthorizationAndStart() {
        guard HKHealthStore.isHealthDataAvailable(),
              let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else { return }
        
        healthStore.requestAuthorization(toShare: [], read: [heartRateType]) { [weak self] success, _ in
            guard success, let self = self else { return }
            DispatchQueue.main.async {
                self.startHeartRateQuery()
            }
        }
    }
    
    private func startHeartRateQuery() {
        guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else { return }
        
        let query = HKAnchoredObjectQuery(
            type: heartRateType,
            predicate: nil,
            anchor: nil,
            limit: HKObjectQueryNoLimit
        ) { [weak self] _, samples, _, _, _ in
            self?.processSamples(samples)
        }
        query.updateHandler = { [weak self] _, samples, _, _, _ in
            self?.processSamples(samples)
        }
        healthStore.execute(query)
        anchoredQuery = query
    }
}

extension HeartRateMonitor: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {}
}

private extension HeartRateMonitor {
    func processSamples(_ samples: [HKSample]?) {
        guard let samples = samples as? [HKQuantitySample] else { return }
        let unit = HKUnit(from: "count/min")
        for sample in samples.reversed() {
            let bpm = sample.quantity.doubleValue(for: unit)
            DispatchQueue.main.async {
                self.lastHeartRate = bpm
            }
            if bpm >= heartRateSpikeThreshold {
                self.sendSpikeToPhone(bpm: bpm)
            }
        }
    }
}
