# TapSafe Fallback Check-In System

## Overview
When the Apple Watch is dead, disconnected, or undetected, TapSafe now activates a **fallback check-in system** that periodically prompts the user to confirm their safety via Face ID or Passcode authentication.

## System Flow

### Detection Phase (45-second window)
1. Walk starts → `watchDetected` flag reset to `false`
2. Watch sends heart rate data → `watchDetected = true`
3. If no data received after 45 seconds → Assume watch unavailable
4. Status message changes to: **"⏱️ Watch not detected. Starting periodic check-ins..."**
5. **Periodic check-in timer starts** based on configurable interval (1-30 minutes)

### Check-In Phase (Every interval)
1. Timer fires → Periodic check-in triggered
2. **High-priority notification** with sound + haptic vibration sent
3. **CheckInAuthenticationView modal** appears over WalkActiveView
4. User must authenticate with **Face ID or Passcode**

### Response Handling

#### ✅ Successful Authentication
- Modal dismisses
- Check-in marked complete
- Failed attempts counter resets to 0
- Timer restarts for next interval

#### ❌ Failed Authentication
- Counter increments (shown in modal as "Failed attempts: X")
- If this is **second consecutive failure** (failedCheckIns >= 1):
  - Shows red warning: "Next: Emergency Contact"
  - After 60 seconds with no response → **Escalates to emergency contact**
  - Call + SMS with GPS location sent to emergency contact

## Configuration

### Check-In Interval Slider
Located on **ContentView.swift** (home screen):
- **Range**: 1-30 minutes
- **Default**: 5 minutes
- **Theme**: Orange with bell icon
- **Persistence**: Stored in UserDefaults via SafetyStore

### Example Intervals
- **1 minute**: Most aggressive monitoring (testing/high-risk area)
- **5 minutes**: Recommended for typical walks (default)
- **15-30 minutes**: Less intrusive for longer walks

## Implementation Details

### Core Components

#### 1. **SafetyManager.swift** Updates
**New Properties:**
```swift
@Published var showCheckInAlert: Bool = false      // Trigger modal display
@Published var failedCheckIns: Int = 0             // Track consecutive failures
private var watchDetected: Bool = false            // Monitor watch presence
private var checkInTimer: Timer?                   // Periodic timer reference
```

**New Methods:**
- `startPeriodicCheckInTimer()` - Start timer firing every interval
- `stopPeriodicCheckInTimer()` - Clean up timer
- `triggerPeriodicCheckIn()` - Called by timer, shows modal
- `completeCheckIn()` - Called on successful auth, restarts timer
- `failedCheckInAttempt()` - Called on failed auth, increments counter

**Modified Methods:**
- `setupCallbacks()` - Now detects watch presence via `onHeartRateUpdate`
- `startWalk()` - Resets check-in state, schedules 45-sec watch detection check
- `endWalk()` - Stops periodic timer on walk end

#### 2. **CheckInAuthenticationView.swift** (New)
Comprehensive authentication modal with:
- **Face ID/Passcode prompt** using LocalAuthentication framework
- **60-second countdown** to next check-in
- **Failed attempts counter** with escalation warning
- **Auto-retry on appear**
- **Error handling** for all LAError codes
- **Fallback** to passcode option

**Key Features:**
- Interrupts with green checkmark icon and prominent layout
- Real-time countdown progress bar
- Shows "Next: Emergency Contact" after 1 failed attempt
- Dismisses automatically on success
- Haptic feedback on authentication results

#### 3. **SafetyNotificationService.swift** Updates
**New Method:**
```swift
func sendCheckInNotification(
    title: String,
    body: String,
    sound: Bool = true,
    haptic: Bool = true
)
```
- High-priority notification (.critical)
- Immediate haptic feedback (UINotificationFeedbackGenerator)
- Custom sound + badge
- Appears on lock screen

#### 4. **WalkActiveView.swift** Updates
Added overlay integration:
```swift
.overlay(alignment: .center) {
    if safetyManager.showCheckInAlert {
        CheckInAuthenticationView(safetyManager: safetyManager)
            .transition(.scale(scale: 0.95).combined(with: .opacity))
    }
}
```

#### 5. **SafetyModels.swift** Updates
**New Property in SafetyStore:**
```swift
@Published var checkInInterval: Double = 5 {
    didSet {
        defaults.set(checkInInterval, forKey: Keys.checkInInterval)
    }
}
```
- Persists to UserDefaults with `checkInInterval` key
- Default value: 5 minutes
- Loaded on init from persistent storage

#### 6. **ContentView.swift** Updates
Orange-themed slider section:
```swift
VStack(alignment: .leading, spacing: 12) {
    HStack {
        Image(systemName: "bell.badge.fill").foregroundColor(.orange)
        Text("Check-In Interval")
        Spacer()
        Text("\(Int(store.checkInInterval)) min")
    }
    Slider(value: $store.checkInInterval, in: 1...30, step: 1).tint(.orange)
    Text("Receive a check-in nudge if watch is undetected")
}
```

## Sequence Diagram

```
Walk Start
    ↓
Check Watch for 45 seconds
    ↓
┌─────────────────────┬──────────────────────┐
│ Watch Data Received │  No Watch Data (45s) │
├─────────────────────┼──────────────────────┤
│ watchDetected=true  │  startPeriodicTimer  │
│ Normal monitoring   │  every N minutes     │
└─────────────────────┴──────────────────────┘
                      ↓
                Notification Sent (sound+haptic)
                CheckInAuthenticationView appears
                      ↓
        ┌─────────────────┬──────────────┐
        │  Auth Success   │  Auth Failed │
        ├─────────────────┼──────────────┤
        │ failedCheckIns  │ increment    │
        │ Reset to 0      │ failedCheckIns
        │ Restart Timer   │ Show warning │
        │ Modal dismisses │ Retry or wait│
        └─────────────────┴──────────────┘
                                ↓
                    If failedCheckIns >= 1
                    AND no response in 60s
                                ↓
                    ESCALATE TO EMERGENCY CONTACT
                    (call + SMS with GPS)
```

## Testing Checklist

- [ ] Disconnect Apple Watch or let battery drain
- [ ] Start walk → Verify "Watch not detected" message appears after 45 seconds
- [ ] Verify check-in interval slider on ContentView works (1-30 min range)
- [ ] Wait for periodic notification → Should have sound + haptic
- [ ] CheckInAuthenticationView modal appears
- [ ] Authenticate with Face ID → Modal dismisses, timer restarts
- [ ] Failed auth → "Failed attempts: 1" shown with warning
- [ ] Wait 60 seconds without responding → Emergency contact called/SMSed
- [ ] Change check-in interval to 1 min, verify faster prompts
- [ ] End walk → Verify timer stops, no more notifications
- [ ] Walk again with watch connected → Normal monitoring, no periodic checks

## Debug Logging

All components use emoji-prefixed logging:
- 🔔 = Check-in system events
- ✅ = Success states
- ❌ = Errors/failures
- ⚠️ = Warnings
- ⏱️ = Timer events

**Example log flow:**
```
⏱️ [SafetyManager] Watch not detected after 45 seconds - starting fallback check-in timer
🔔 [SafetyManager] Periodic check-in timer started - interval: 5 min
🔔 [SafetyManager] Periodic check-in triggered - failed attempts: 0
🔔 [Notifications] Sending check-in notification: Check-In Required
✅ [Notifications] Check-in notification sent successfully
📱 [CheckInAuth] Authentication successful
✅ [SafetyManager] Check-in completed successfully - resetting timer
```

## Error Handling

### LocalAuthentication Errors
- **authenticationFailed**: User enters wrong biometric/passcode
- **userCancel**: User taps "Cancel"
- **userFallback**: User taps "Use Passcode"
- All trigger failedCheckInAttempt() increment

### Notification Errors
- If notification fails to send, error logged but doesn't block escalation logic
- 60-second timeout still applies

### Edge Cases
- **Watch reconnects during check-in**: watchDetected=true stops timer before next interval
- **Multiple check-ins in queue**: Each sets unique UUID identifier
- **User leaves app**: Notifications still fire (iOS background capability)
- **Battery dies before escalation**: Last check-in triggers escalation countdown before power loss

## Security & Privacy

- **Face ID/Passcode**: Device-level authentication, no data sent to TapSafe
- **GPS Location**: Only sent to emergency contact in escalation SMS
- **Check-in history**: Not retained after walk ends (stateless per-walk)
- **Interval storage**: Only stored locally in UserDefaults
- **Notifications**: High-priority but don't reveal exact location until escalation

## Known Limitations

1. **LocalAuthentication**: Requires at least one biometric or passcode configured on device
2. **Notification timing**: iOS may batch/delay notifications if system is busy
3. **Escalation call**: Requires user to be reachable (not in airplane mode)
4. **Timer precision**: DispatchSourceTimer ±10ms accuracy typical, system load dependent
5. **Background**: Check-ins work in background but notification prominence depends on iOS state

## Future Enhancements

1. **Configurable escalation**: Let user choose escalation after 1st vs 2nd vs 3rd failure
2. **Smart interval**: Reduce interval if multiple failed check-ins
3. **Watch recovery**: Auto-resume normal monitoring if watch reconnects mid-walk
4. **Fallback contacts**: Try multiple emergency contacts before giving up
5. **Check-in history**: Log failed/successful check-ins for post-walk review
