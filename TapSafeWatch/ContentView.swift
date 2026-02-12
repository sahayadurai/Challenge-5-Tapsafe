//
//  ContentView.swift
//  TapSafeWatch
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var heartRateMonitor: HeartRateMonitor
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "heart.fill")
                .font(.title)
                .foregroundColor(.red)
            Text("TapSafe")
                .font(.headline)
            if let bpm = heartRateMonitor.lastHeartRate {
                Text("\(Int(bpm)) bpm")
                    .font(.title2)
            } else {
                Text("Monitoring...")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .onAppear {
            heartRateMonitor.startMonitoring()
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(HeartRateMonitor())
}
