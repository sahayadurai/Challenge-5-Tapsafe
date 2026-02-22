import SwiftUI

struct ContentView: View {
    @StateObject private var store = SafetyStore()
    @State private var showingWalkScreen = false
    @State private var showingDestination = false
    @State private var showingEmergencyContact = false

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "hand.tap.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 80, height: 80)
                .foregroundColor(.blue)

            Text("TapSafe")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Your passive walk-home guardian")
                .font(.title3)
                .foregroundColor(.secondary)

            VStack(spacing: 12) {
                Button {
                    showingDestination = true
                } label: {
                    HStack {
                        Image(systemName: "mappin.circle.fill")
                        Text(store.destination != nil ? "Destination set" : "Set destination")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue.opacity(0.15))
                    .foregroundColor(.blue)
                    .cornerRadius(12)
                }

                Button {
                    showingEmergencyContact = true
                } label: {
                    HStack {
                        Image(systemName: "person.2.fill")
                        Text(store.emergencyContact != nil ? "\(store.emergencyContact!.name)" : "Set emergency contact")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.orange.opacity(0.15))
                    .foregroundColor(.orange)
                    .cornerRadius(12)
                }
            }
            .padding(.horizontal, 24)
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "heart.fill")
                        .foregroundColor(.red)
                    Text("Heart Rate Threshold")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Spacer()
                    Text("\(Int(store.heartRateThreshold)) BPM")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.red)
                }
                Slider(value: $store.heartRateThreshold, in: 80...180, step: 5)
                    .tint(.red)
                Text("Alert when heart rate exceeds this threshold")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color.red.opacity(0.08))
            .cornerRadius(12)
            .padding(.horizontal, 24)

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "bell.badge.fill")
                        .foregroundColor(.orange)
                    Text("Check-In Interval")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Spacer()
                    Text("\(Int(store.checkInInterval)) min")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.orange)
                }
                Slider(value: $store.checkInInterval, in: 1...30, step: 1)
                    .tint(.orange)
                Text("Receive a check-in nudge if watch is undetected")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color.orange.opacity(0.08))
            .cornerRadius(12)
            .padding(.horizontal, 24)

            Button("Start Walk") {
                showingWalkScreen = true
            }
            .padding()
            .frame(maxWidth: 300)
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(12)
            .shadow(radius: 6)
            .disabled(store.emergencyContact == nil)

            if store.emergencyContact == nil {
                Text("Set an emergency contact to start a walk.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding()
        .sheet(isPresented: $showingWalkScreen) {
            WalkActiveView(store: store)
        }
        .sheet(isPresented: $showingDestination) {
            DestinationPickerView(destination: $store.destination)
        }
        .sheet(isPresented: $showingEmergencyContact) {
            EmergencyContactView(contact: $store.emergencyContact)
        }
    }
}

#Preview {
    ContentView()
}
