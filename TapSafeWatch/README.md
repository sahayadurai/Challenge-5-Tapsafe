# TapSafe Watch App

This folder contains the **watchOS** app source for TapSafe. It uses **HealthKit** to read heart rate and **WatchConnectivity** to send spike events to the iPhone app.

## Adding the Watch target in Xcode

1. In Xcode: **File → New → Target**
2. Choose **Watch App** (under watchOS), then **Next**
3. Name the product **TapSafeWatch** (or keep default), uncheck "Include Notification Scene" if you like, **Finish**
4. When Xcode creates the template, **replace** the template Swift files with the ones in this folder, or add this folder’s files to the Watch app target:
   - `TapSafeWatchApp.swift`
   - `ContentView.swift`
   - `HeartRateMonitor.swift`
5. In the **Watch App target** → **Signing & Capabilities**, add **HealthKit** and ensure the Watch app’s bundle ID is the same app group as the iOS app if you use app groups (e.g. `com.sahaya.TapSafe.watchkitapp`).
6. In the **Watch App’s Info.plist** (or target Info), add **Privacy - Health Share Usage Description** for heart rate.

After that, build and run the iOS app and the Watch app; when the Watch sends a heart rate spike, the iPhone will receive it and trigger a check-in.
