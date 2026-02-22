//
//  SafetyModels.swift
//  TapSafe
//
//  Passive safety: destination, emergency contact, and check-in state.
//

import Combine
import CoreLocation
import Foundation
import SwiftUI

// MARK: - Destination (designated safe area)

struct Destination: Codable, Equatable {
    var latitude: Double
    var longitude: Double
    /// Radius in meters; user is "in designated area" when within this of destination.
    var radiusMeters: Double
    
    var coordinate: CLLocationCoordinate2D {
        get { CLLocationCoordinate2D(latitude: latitude, longitude: longitude) }
        set { latitude = newValue.latitude; longitude = newValue.longitude }
    }
    
    var location: CLLocation { CLLocation(latitude: latitude, longitude: longitude) }
    
    static let defaultRadius: Double = 100
}

// MARK: - Emergency Contact

struct EmergencyContact: Codable, Equatable {
    var name: String
    var phoneNumber: String
}

// MARK: - Check-in state (for escalation)

enum CheckInState: String, Codable {
    case none           // No check-in pending
    case checkInSent    // Check-in notification sent, waiting for response
    case respondedSafe  // User tapped "I'm Safe"
    case escalated      // No response; emergency contact alerted
}

// MARK: - Persistence

final class SafetyStore: ObservableObject {
    private let defaults = UserDefaults.standard
    private enum Keys {
        static let destination = "tapsafe.destination"
        static let emergencyContact = "tapsafe.emergencyContact"
        static let heartRateThreshold = "tapsafe.heartRateThreshold"
        static let checkInInterval = "tapsafe.checkInInterval"
    }
    
    @Published var destination: Destination? {
        didSet {
            if let d = destination, let data = try? JSONEncoder().encode(d) {
                defaults.set(data, forKey: Keys.destination)
            } else {
                defaults.removeObject(forKey: Keys.destination)
            }
        }
    }
    
    @Published var emergencyContact: EmergencyContact? {
        didSet {
            if let c = emergencyContact, let data = try? JSONEncoder().encode(c) {
                defaults.set(data, forKey: Keys.emergencyContact)
            } else {
                defaults.removeObject(forKey: Keys.emergencyContact)
            }
        }
    }
    
    @Published var heartRateThreshold: Double = 120 {
        didSet {
            defaults.set(heartRateThreshold, forKey: Keys.heartRateThreshold)
        }
    }
    
    @Published var checkInInterval: Double = 5 {
        didSet {
            defaults.set(checkInInterval, forKey: Keys.checkInInterval)
        }
    }
    
    init() {
        if let data = defaults.data(forKey: Keys.destination),
           let d = try? JSONDecoder().decode(Destination.self, from: data) {
            destination = d
        } else {
            destination = nil
        }
        if let data = defaults.data(forKey: Keys.emergencyContact),
           let c = try? JSONDecoder().decode(EmergencyContact.self, from: data) {
            emergencyContact = c
        } else {
            emergencyContact = nil
        }
        heartRateThreshold = defaults.double(forKey: Keys.heartRateThreshold) > 0 ? defaults.double(forKey: Keys.heartRateThreshold) : 120
        checkInInterval = defaults.double(forKey: Keys.checkInInterval) > 0 ? defaults.double(forKey: Keys.checkInInterval) : 5
    }
}
