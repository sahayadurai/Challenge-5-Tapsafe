//
//  TapSafeApp.swift
//  TapSafe
//
//  Created by Sahaya Muthukani Gnanadurai on 12/02/26.
//

import SwiftUI

@main
struct TapSafeApp: App {
    init() {
        WatchConnectivityManager.shared.activate()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
