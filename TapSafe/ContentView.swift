import SwiftUI

struct ContentView: View {
    @StateObject private var store = SafetyStore()
    @State private var showingWalkScreen = false
    @State private var showingDestination = false
    @State private var showingEmergencyContact = false

    var body: some View {
        VStack(spacing: 32) {
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
