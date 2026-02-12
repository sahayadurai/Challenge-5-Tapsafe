import SwiftUI
import UserNotifications

struct WalkActiveView: View {
    @Environment(\.dismiss) var dismiss
    
    @State private var status = "Starting your safe walk..."

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
            
            Text(status)
                .font(.body)
                .foregroundColor(.secondary)
            
            Button("End Walk") {
                dismiss()
            }
            .padding()
            .background(Color.gray.opacity(0.2))
            .cornerRadius(10)
            
            Spacer()
        }
        .padding()
        .onAppear {
            simulateSafetyCheck()
        }
    }
    
    private func simulateSafetyCheck() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            self.status = "🚶 Monitoring your route..."
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 8) {
            self.status = "⚠️ Unusual stop detected"
            self.sendSafetyCheck()
        }
    }
    
    private func sendSafetyCheck() {
        print("🔔 Requesting notification permission...")
        
        let center = UNUserNotificationCenter.current()
        
        // Step 1: Request permission
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ Notification permission error: \(error)")
                    self.status = "Notification error."
                    return
                }
                
                if !granted {
                    print("❌ Notifications denied by user.")
                    self.status = "Notifications disabled."
                    return
                }
                
                print("✅ Notification permission granted.")
                
                // Step 2: Define action
                let safeAction = UNNotificationAction(
                    identifier: "safe-action",
                    title: "I'm Safe",
                    options: [.foreground] // opens app when tapped
                )
                
                // Step 3: Define category
                let category = UNNotificationCategory(
                    identifier: "safety-check",
                    actions: [safeAction],
                    intentIdentifiers: [],
                    options: []
                )
                
                // Register category
                center.setNotificationCategories([category])
                
                // Step 4: Create notification
                let content = UNMutableNotificationContent()
                content.title = "TapSafe Check-In"
                content.body = "Are you okay? Tap to confirm you're safe."
                content.categoryIdentifier = "safety-check" // must match!
                content.sound = .default
                
                let request = UNNotificationRequest(
                    identifier: UUID().uuidString,
                    content: content,
                    trigger: nil // deliver immediately
                )
                
                // Step 5: Send it
                center.add(request) { error in
                    if let error = error {
                        print("❌ Failed to send notification: \(error)")
                        self.status = "Failed to send alert."
                    } else {
                        print("✅ Notification sent successfully!")
                        self.status = "Safety check sent."
                    }
                }
            }
        }
    }
}

#Preview {
    WalkActiveView()
}
