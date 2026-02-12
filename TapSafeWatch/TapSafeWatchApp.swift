//
//  TapSafeWatchApp.swift
//  TapSafeWatch
//
//  watchOS app: monitors heart rate via HealthKit, sends spike to iPhone via WatchConnectivity.
//

import SwiftUI

@main
struct TapSafeWatchApp: App {
    @StateObject private var heartRateMonitor = HeartRateMonitor()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(heartRateMonitor)
        }
    }
}
