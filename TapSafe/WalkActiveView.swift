import SwiftUI

struct WalkActiveView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var store: SafetyStore

    @StateObject private var safetyManager: SafetyManager
    @StateObject private var notificationService = SafetyNotificationService.shared

    init(store: SafetyStore) {
        _store = ObservedObject(wrappedValue: store)
        _safetyManager = StateObject(wrappedValue: SafetyManager(store: store))
    }

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "moon.stars.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 70, height: 70)
                .foregroundColor(.purple)

            Text("Walking Home")
                .font(.title2)
                .fontWeight(.semibold)

            Text(safetyManager.statusMessage)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            if notificationService.checkInState == .checkInSent {
                Button("I'm Safe") {
                    safetyManager.userRespondedSafe()
                }
                .padding()
                .frame(maxWidth: 280)
                .background(Color.green)
                .foregroundColor(.white)
                .cornerRadius(12)
            }

            if notificationService.checkInState == .escalated {
                Text("Emergency contact is being notified with your location.")
                    .font(.subheadline)
                    .foregroundColor(.orange)
                    .padding(.horizontal)
            }

            Spacer()

            Button("End Walk") {
                safetyManager.endWalk()
                dismiss()
            }
            .padding()
            .background(Color.gray.opacity(0.2))
            .cornerRadius(10)
        }
        .padding()
        .onAppear {
            safetyManager.startWalk()
        }
        .onDisappear {
            safetyManager.endWalk()
        }
    }
}

#Preview {
    WalkActiveView(store: SafetyStore())
}
