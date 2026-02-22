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

            // Real-time Heart Rate Display
            if let heartRate = safetyManager.currentHeartRate {
                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        Image(systemName: "heart.fill")
                            .font(.title3)
                            .foregroundColor(.red)
                            .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: safetyManager.currentHeartRate)
                        Text("\(Int(heartRate)) BPM")
                            .font(.title3)
                            .fontWeight(.semibold)
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("Threshold: \(Int(store.heartRateThreshold)) BPM")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            if heartRate >= store.heartRateThreshold {
                                Text("⚠️ Above threshold")
                                    .font(.caption2)
                                    .foregroundColor(.orange)
                            }
                        }
                    }
                    .padding()
                    .background(Color.red.opacity(0.08))
                    .cornerRadius(10)
                }
                .padding(.horizontal)
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "heart.slash.fill")
                        .font(.title3)
                        .foregroundColor(.gray)
                    Text("Heart rate not detected")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color.gray.opacity(0.08))
                .cornerRadius(10)
                .padding(.horizontal)
            }

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
        // Show authentication modal when periodic check-in is triggered
        .overlay(alignment: .center) {
            if safetyManager.showCheckInAlert {
                CheckInAuthenticationView(safetyManager: safetyManager)
                    .transition(.scale(scale: 0.95).combined(with: .opacity))
            }
        }
    }
}

#Preview {
    WalkActiveView(store: SafetyStore())
}
