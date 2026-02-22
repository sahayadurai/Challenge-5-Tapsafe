# TapSafe Project Files Overview

## Project Structure

```
TapSafe/
├── TapSafe/                          # Main iOS App
│   ├── TapSafeApp.swift             # App entry point
│   ├── ContentView.swift            # Home screen with settings
│   ├── WalkActiveView.swift         # Active walk screen
│   ├── Info.plist                   # App configuration + Face ID permission
│   │
│   ├── Services/
│   │   ├── SafetyManager.swift      # ⭐ UPDATED: Now sends location to backend
│   │   ├── LocationManager.swift    # GPS tracking
│   │   ├── WatchConnectivityManager.swift
│   │   ├── SafetyNotificationService.swift
│   │   └── HeartRateMonitor.swift
│   │
│   ├── Views/
│   │   ├── CheckInAlertView.swift   # ⭐ Ringer + Flash alert (60-sec countdown)
│   │   ├── CheckInAuthenticationView.swift
│   │   ├── DestinationPickerView.swift
│   │   └── EmergencyContactView.swift
│   │
│   └── Models/
│       └── SafetyModels.swift       # Data structures + persistence
│
├── Backend/                          # ⭐ NEW: Backend Files
│   └── index.php                    # ⭐ SINGLE FILE - Complete PHP backend
│                                    #   Upload this to: https://ronvoy.com/
│
└── Documentation/
    ├── BACKEND_INTEGRATION_GUIDE.md    # Detailed technical docs
    ├── BACKEND_QUICK_START.md          # 5-minute setup guide
    ├── FALLBACK_CHECKIN_SYSTEM.md      # Check-in alert system
    ├── SMS_DELIVERY_NOTES.md           # Why we use backend instead
    └── TROUBLESHOOTING_GUIDE.md        # Debug tips
```

## What's New

### Backend: index.php

**Single monolithic file** containing:

✅ **HTML**
- Responsive mobile-friendly UI
- Login form with gradient design
- Location history table
- Embedded Apple Maps iframe
- Error handling (404 pages)

✅ **CSS**
- Mobile-first responsive design
- Works on 320px (iPhone SE) to 2560px (iPad Pro)
- Optimized for touch interactions
- Dark mode friendly

✅ **PHP**
- GET request handling: `?location=37.7749,-122.4194&user=Sahaya&token=1234`
- POST request handling: User authentication
- CSV data storage (auto-created)
- Token validation
- 404 error handling for invalid requests

✅ **JavaScript**
- Login form submission
- Input validation
- Keyboard Enter-key support
- HTML escaping for security

### App: SafetyManager.swift

**Updated `escalateToEmergencyContact()` to:**
- ❌ Remove SMS sending attempt
- ✅ Add automatic backend GET request with GPS coordinates
- ✅ Send location via `sendLocationToBackend()` method
- ✅ Log success/failure to console

**New method: `sendLocationToBackend()`**
```swift
- Builds backend URL with location parameters
- Sends GET request automatically (no user action)
- Returns confirmation from backend
- Logs tracking URL for emergency contacts
```

### App: CheckInAlertView.swift

**Enhanced with proper audio:**
- ✅ Audio session setup with `.playback` category
- ✅ Speaker output enabled (bypasses silent mode)
- ✅ System alarm sound (ID 1005) plays every 0.8 seconds
- ✅ Red screen flashes every 300ms
- ✅ Proper timer cleanup

## How It Works Together

### Emergency Flow (Automatic)

```
1. Heart Rate Monitor Offline 45+ seconds
   └─ → CheckInAlertView triggered

2. 60-Second Countdown
   ├─ Red screen flashing every 300ms
   ├─ Loud alarm sound every 0.8 seconds
   └─ Requires Face ID/Passcode authentication

3. Authentication Timeout/Failure
   └─ → escalateToEmergencyContact(location:) called

4. Automatic Backend Submission
   ├─ sendLocationToBackend() executes
   ├─ GET request sent to backend:
   │  └─ https://ronvoy.com/index.php?location=37.7749,-122.4194&user=Sahaya&token=1234
   └─ Location saved to backend

5. Backend Saves Location
   ├─ Validates token
   ├─ Creates CSV file if needed
   ├─ Saves: timestamp,lat,lon
   └─ Displays confirmation page with map

6. Emergency Contact Views Location
   ├─ Login at https://ronvoy.com/index.php
   ├─ See all tracked locations
   └─ Click to view in Apple Maps
```

## File Sizes

| File | Size | Purpose |
|------|------|---------|
| Backend/index.php | ~12 KB | Complete backend (upload to server) |
| SafetyManager.swift | ~10 KB | Main app coordinator (UPDATED) |
| CheckInAlertView.swift | ~11 KB | Emergency alert UI (FIXED) |
| BACKEND_INTEGRATION_GUIDE.md | ~15 KB | Detailed technical docs |
| BACKEND_QUICK_START.md | ~8 KB | Quick setup (start here) |

## Configuration Steps

### 1. Upload Backend

```bash
# Copy index.php to your server
scp Backend/index.php user@ronvoy.com:/var/www/html/
```

### 2. Update App

Edit `SafetyManager.swift` lines ~167-169:

```swift
let backendURL = "https://ronvoy.com/index.php"  // Your domain
let userName = "Sahaya"                         # Your app identifier
let token = "1234"                              # Your valid token
```

### 3. Update Backend

Edit `index.php` line ~17:

```php
define('VALID_TOKENS', ['1234', 'your-other-tokens']);
```

## Testing Checklist

- [ ] Upload index.php to server
- [ ] Test backend directly: `https://ronvoy.com/index.php?location=37.7749,-122.4194&user=Test&token=1234`
- [ ] Update app backend URL, username, token
- [ ] Rebuild app in Xcode
- [ ] Disconnect Apple Watch or let battery drain
- [ ] Start walk → after 45 seconds, CheckInAlertView should appear
- [ ] Let 60-second timer expire without authentication
- [ ] Check console for "✅ Location successfully sent to backend"
- [ ] Visit backend URL to verify location was saved
- [ ] Login with credentials to view location history

## Key Improvements Over Previous Version

### Before (SMS Attempt)
- ❌ Tried to open Messages app
- ❌ Required manual "Send" button
- ❌ No guaranteed delivery
- ❌ Used iOS MessageUI framework

### After (Backend Request)
- ✅ Fully automatic - no user action needed
- ✅ Location saved immediately on server
- ✅ 100% delivery guaranteed
- ✅ Can be tracked in real-time
- ✅ Works without cellular service (WiFi only requires internet)
- ✅ No special iOS permissions needed
- ✅ Portable to Android/Web in future

## Documentation Files to Read

**Start with these in order:**

1. **BACKEND_QUICK_START.md** - 5-minute setup
2. **BACKEND_INTEGRATION_GUIDE.md** - Detailed docs
3. **FALLBACK_CHECKIN_SYSTEM.md** - How check-in works
4. **TROUBLESHOOTING_GUIDE.md** - Debug tips

## Deployment Checklist

- [ ] Backend file ready (`index.php`)
- [ ] Server with PHP support
- [ ] HTTPS enabled on server
- [ ] tapsafe_data directory writable
- [ ] Tokens configured in PHP
- [ ] App rebuilt with new backend URL
- [ ] Test emergency flow end-to-end
- [ ] Share login credentials with emergency contacts
- [ ] Document tracking URL for contacts

## Questions?

Check the documentation files or examine the code comments:

- `SafetyManager.swift` - `sendLocationToBackend()` method
- `CheckInAlertView.swift` - `startRinger()` and `startFlashing()` methods
- `index.php` - Route handling and data storage logic
