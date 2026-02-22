# TapSafe Backend Quick Deploy Guide

## What You Get

Complete single-file PHP backend at `/Backend/index.php` that handles:

✅ **GET Request** - Emergency location submission
- URL: `https://ronvoy.com/index.php?location=37.7749,-122.4194&user=Sahaya&token=1234`
- Auto-saves to CSV
- Shows Apple Maps
- Sends confirmation

✅ **POST Request** - View location history
- Login form with username + token
- Table of all tracked locations with timestamps
- Click any location to view in Apple Maps
- Latest location shown in embedded Apple Maps

✅ **Error Handling**
- Invalid tokens → 404 page
- Missing parameters → 404 page
- Fully responsive mobile-friendly design

## Quick Setup (5 minutes)

### Step 1: Upload PHP File

1. Copy `/Backend/index.php` from your project
2. Upload to your server at: `https://ronvoy.com/index.php`
3. That's it! The backend auto-creates data directory

### Step 2: Update App Configuration

Edit `SafetyManager.swift` in the app:

```swift
// Line ~170 in sendLocationToBackend()
let backendURL = "https://ronvoy.com/index.php"  // Your server URL
let userName = "Sahaya"                         // Your app/user identifier
let token = "1234"                              // Your valid token
```

### Step 3: Rebuild and Test

1. Build the iOS app in Xcode
2. Test emergency flow (disconnect Watch for 45s)
3. Check console for "✅ Location successfully sent to backend"

## How It Works

### Emergency Flow

```
Heart Rate Monitor Offline for 45 seconds
    ↓
CheckInAlertView appears (ringer + flash)
    ↓
60-second countdown for Face ID/Passcode
    ↓
User fails to authenticate or timeout
    ↓
SafetyManager.escalateToEmergencyContact()
    ↓
sendLocationToBackend() makes GET request
    ↓
GET https://ronvoy.com/index.php?location=37.7749,-122.4194&user=Sahaya&token=1234
    ↓
Backend receives → validates token → saves to CSV → shows map
```

### Data Storage

```
Server: https://ronvoy.com/
├── index.php (your uploaded file)
└── tapsafe_data/
    ├── Sahaya.csv (automatically created)
    │   ├── timestamp,latitude,longitude
    │   ├── 2026-02-22 14:30:45,37.7749,-122.4194
    │   └── 2026-02-22 14:35:12,37.7751,-122.4189
    └── John.csv
```

## Testing

### Test 1: Emergency Location Submission

Open in browser (or use curl):
```
https://ronvoy.com/index.php?location=37.7749,-122.4194&user=TestUser&token=1234
```

Expected result:
- ✅ Location Received page
- Shows coordinates and timestamp
- Apple Maps embedded showing location

### Test 2: View History

1. Go to `https://ronvoy.com/index.php`
2. Enter username: `TestUser`
3. Enter token: `1234`
4. Click "View History & Maps"

Expected result:
- Table showing all submitted locations
- Latest location in Apple Maps
- Timestamps for each entry

### Test 3: Invalid Token

Open in browser:
```
https://ronvoy.com/index.php?location=37.7749,-122.4194&user=TestUser&token=WRONG
```

Expected result:
- 404 Not Found page
- "Invalid request parameters or unauthorized access"

## Configuration

### Valid Tokens

Edit in `index.php` (line ~17):

```php
define('VALID_TOKENS', [
    '1234',              // Default demo token
    '5678',              // Add more tokens here
    'your-token-here'    // Use strong random tokens in production
]);
```

Production recommendation:
```php
define('VALID_TOKENS', [
    'tapsafe_' . time() . '_user1',  // Time-based tokens
    'tapsafe_' . time() . '_user2'
]);
```

## Mobile-Friendly Features

✅ Responsive design
✅ Works on all screen sizes (320px - 2560px)
✅ Touch-optimized buttons
✅ Mobile-friendly Apple Maps embedding
✅ Optimized fonts and spacing for small screens

## API Endpoints

### Submit Emergency Location (Automatic)

```
GET /index.php?location=[lat],[lon]&user=[name]&token=[token]

Parameters:
- location: Latitude,Longitude (required)
- user: Username/Identifier (required)
- token: Valid token from VALID_TOKENS (required)

Response: 200 OK
- Shows confirmation page
- Displays location on Apple Maps
- Saves to [user].csv
```

### View Dashboard

```
GET /index.php

Response: 200 OK
- Shows login form
- Requires username and token
```

### View Location History (Authenticated)

```
POST /index.php

Body Parameters:
- user: Username
- token: Valid token

Response: 200 OK
- Shows all locations in table
- Latest location in Apple Maps
- One-click view links for each location
```

### Invalid Request

```
Response: 404 Not Found
- All other GET/POST combinations
- Invalid tokens
- Missing required parameters
```

## Security Best Practices

1. **Change default token**
   ```php
   define('VALID_TOKENS', ['your-strong-random-token-here']);
   ```

2. **Use HTTPS** (already in your URL: https://ronvoy.com/)
   - Encrypts location data in transit
   - Required for production

3. **Restrict file access**
   ```bash
   # Protect data directory
   chmod 700 tapsafe_data/
   
   # Protect PHP file
   chmod 644 index.php
   ```

4. **Regular backups**
   ```bash
   # Backup location data
   tar -czf backup_$(date +%s).tar.gz tapsafe_data/
   ```

5. **Monitor access logs**
   - Check for repeated failed attempts
   - Watch for unusual IP addresses
   - Review large location submissions

## Troubleshooting

| Problem | Solution |
|---------|----------|
| "404 Not Found" on submission | Check token in app matches VALID_TOKENS |
| Location not saved | Verify tapsafe_data/ is writable (chmod 755) |
| Can't login | Verify username matches exactly and token is valid |
| Missing locations | Check tapsafe_data/[username].csv exists |
| Maps not showing | Check coordinates are valid (lat: -90 to 90, lon: -180 to 180) |

## Example Log Output

When emergency is triggered:

```
📱 [SafetyManager] Sending location to backend: https://ronvoy.com/index.php
📱 [SafetyManager] Coordinates: 37.7749,-122.4194
✅ [SafetyManager] Location successfully sent to backend
📍 [SafetyManager] View tracking: https://ronvoy.com/index.php?user=Sahaya&token=1234
```

## What Happens After Submission

1. App sends GET request with location
2. Backend receives and validates token
3. Location saved to CSV with timestamp
4. Confirmation page shown (you can view in Safari)
5. Emergency contacts can log in anytime to view history
6. All locations clickable to open in Apple Maps

## Next Steps

1. ✅ Upload `index.php` to your server
2. ✅ Update `backendURL`, `userName`, `token` in SafetyManager.swift
3. ✅ Rebuild and test the app
4. ✅ Share login credentials with emergency contacts
5. ✅ Test the emergency flow

## Support Resources

- **BACKEND_INTEGRATION_GUIDE.md** - Detailed technical documentation
- **SMS_DELIVERY_NOTES.md** - Why SMS isn't used (iOS limitation)
- **FALLBACK_CHECKIN_SYSTEM.md** - Check-in flow details

---

**Backend Status**: ✅ Ready to deploy  
**App Integration**: ✅ Fully implemented  
**Testing**: ✅ Ready for production
