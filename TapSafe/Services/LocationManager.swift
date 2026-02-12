//
//  LocationManager.swift
//  TapSafe
//
//  Tracks movement and detects "stopped for 2+ minutes" outside designated area.
//

import Combine
import CoreLocation
import Foundation
import SwiftUI

/// Movement considered "stopped" if user doesn't move more than this (meters).
private let stoppedDistanceThreshold: CLLocationDistance = 25

/// Minimum time stationary in a non-designated area before triggering check-in (seconds).
let stationaryTriggerInterval: TimeInterval = 120 // 2 minutes

final class LocationManager: NSObject, ObservableObject {
    private let manager = CLLocationManager()
    
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var lastLocation: CLLocation?
    @Published var isInDesignatedArea: Bool = false
    
    /// When we first detected the user stationary (in non-designated area); nil if moving or in designated area.
    private var stationarySince: Date?
    
    /// Callback when user has been stationary in non-designated area for 2+ minutes.
    var onStationaryTooLong: (() -> Void)?
    
    private var destination: Destination?
    
    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 10
        manager.allowsBackgroundLocationUpdates = true
        manager.pausesLocationUpdatesAutomatically = false
        authorizationStatus = manager.authorizationStatus
    }
    
    func requestPermission() {
        manager.requestWhenInUseAuthorization()
        // For background monitoring we need "always" when walk is active; request when starting walk.
    }
    
    func requestAlwaysAuthorization() {
        manager.requestAlwaysAuthorization()
    }
    
    func startUpdatingLocation(destination: Destination?) {
        self.destination = destination
        manager.startUpdatingLocation()
        stationarySince = nil
    }
    
    func stopUpdatingLocation() {
        manager.stopUpdatingLocation()
        destination = nil
        stationarySince = nil
        isInDesignatedArea = false
    }
    
    /// Returns true if `location` is within the designated area (destination radius).
    private func isWithinDesignatedArea(_ location: CLLocation) -> Bool {
        guard let dest = destination else { return false }
        return location.distance(from: dest.location) <= dest.radiusMeters
    }
    
    /// Check if we're effectively stationary (current vs previous location).
    private func isStationary(current: CLLocation, previous: CLLocation?) -> Bool {
        guard let prev = previous else { return false }
        return current.distance(from: prev) <= stoppedDistanceThreshold
    }
    
    private func updateStationaryState(current: CLLocation, previous: CLLocation?) {
        let inDesignated = isWithinDesignatedArea(current)
        isInDesignatedArea = inDesignated
        
        if inDesignated {
            // In designated area: never trigger for "stopped too long".
            stationarySince = nil
            return
        }
        
        let stationary = isStationary(current: current, previous: previous)
        if stationary {
            if stationarySince == nil {
                stationarySince = Date()
            } else if let since = stationarySince, Date().timeIntervalSince(since) >= stationaryTriggerInterval {
                stationarySince = nil
                onStationaryTooLong?()
            }
        } else {
            stationarySince = nil
        }
    }
}

extension LocationManager: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        DispatchQueue.main.async { self.authorizationStatus = status }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        DispatchQueue.main.async {
            let previous = self.lastLocation
            self.lastLocation = location
            self.updateStationaryState(current: location, previous: previous)
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Optionally surface to UI
    }
}
