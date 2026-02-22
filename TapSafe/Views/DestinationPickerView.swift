//
//  DestinationPickerView.swift
//  TapSafe
//
//  Set or edit destination (designated safe area).
//

import SwiftUI
import MapKit

struct DestinationPickerView: View {
    @Binding var destination: Destination?
    @Environment(\.dismiss) var dismiss
    
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
    )
    @State private var selectedCoordinate: CLLocationCoordinate2D?
    @State private var radiusMeters: Double = Destination.defaultRadius
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Map(position: .constant(.region(region))) {
                    ForEach(annotationItems, id: \.id) { item in
                        Annotation("", coordinate: item.coordinate) {
                            Image(systemName: "mappin.circle.fill")
                                .font(.title)
                                .foregroundColor(.red)
                        }
                    }
                }
                .onMapCameraChange { context in
                    region = context.region
                }
                
                Button("Set destination at map center") {
                    selectedCoordinate = region.center
                }
                .padding(.vertical, 8)
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("Safe zone radius: \(Int(radiusMeters)) m")
                        .font(.subheadline)
                    Slider(value: $radiusMeters, in: 50...500, step: 25)
                }
                .padding()
            }
            .navigationTitle("Set Destination")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Use Current Location") {
                        setCurrentLocation()
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Save") {
                        saveDestination()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                if let d = destination {
                    region.center = d.coordinate
                    region.span = MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
                    selectedCoordinate = d.coordinate
                    radiusMeters = d.radiusMeters
                } else {
                    setCurrentLocation()
                }
            }
        }
    }
    
    private var annotationItems: [MapPin] {
        guard let coord = selectedCoordinate ?? destination?.coordinate else { return [] }
        return [MapPin(coordinate: coord)]
    }
    
    private func setCurrentLocation() {
        let manager = CLLocationManager()
        if let loc = manager.location {
            region.center = loc.coordinate
            region.span = MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
            selectedCoordinate = loc.coordinate
        }
    }
    
    private func saveDestination() {
        let coord = selectedCoordinate ?? region.center
        destination = Destination(
            latitude: coord.latitude,
            longitude: coord.longitude,
            radiusMeters: radiusMeters
        )
        dismiss()
    }
}

private struct MapPin: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
}

#Preview {
    DestinationPickerView(destination: .constant(nil))
}
