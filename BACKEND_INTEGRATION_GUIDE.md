# TapSafe Backend Integration Guide

## Overview

The TapSafe app now uses a backend PHP endpoint to automatically track emergency locations without requiring manual SMS sending. When a user fails to respond to check-in alerts, their real-time GPS coordinates are automatically sent to your backend server.

## Backend Setup

### 1. Server Requirements

- PHP 7.0+
- Web server (Apache, Nginx, etc.)
- Write permissions on the server for data storage
- HTTPS enabled (recommended for security)

### 2. Installation

1. Upload the `index.php` file to your server directory:
   ```
   https://ronvoy.com/index.php
   ```

2. The backend will automatically create a `tapsafe_data` directory for storing location history

3. Ensure the web server has write permissions:
   ```bash
   chmod 755 tapsafe_data/
   ```

### 3. Configuration

Edit the `index.php` file to configure valid tokens:

```php
define('VALID_TOKENS', ['1234', '5678', 'your-secure-token']);
```

## Backend Features

### GET Request - Emergency Location Submission

**Automatic trigger**: When user fails authentication during the 60-second check-in window

**URL Format**:
```
https://ronvoy.com/index.php?location=[lat],[lon]&user=[name]&token=[token]
```

**Example**:
```
https://ronvoy.com/index.php?location=37.7749,-122.4194&user=Sahaya&token=1234
```

**Response**: Shows the location on Apple Maps + saves to CSV

### POST Request - View Location History

**Access**: Web dashboard to view tracked locations

1. Navigate to `https://ronvoy.com/index.php`
2. Enter username and token
3. View all location history in table format
4. Click any location to open in Apple Maps

### Data Storage

Locations are stored in CSV files (one per user):

```
tapsafe_data/
├── Sahaya.csv
├── John.csv
└── Emergency.csv
```

**CSV Format**:
```
timestamp,latitude,longitude
2026-02-22 14:30:45,37.7749,-122.4194
2026-02-22 14:35:12,37.7751,-122.4189
```

## iOS App Configuration

### Update Backend URL and Credentials

Edit `SafetyManager.swift` in the `sendLocationToBackend()` method:

```swift
let backendURL = "https://your-domain.com/index.php"  // Your server URL
let userName = "Sahaya"  // User identifier
let token = "1234"       // Valid token from backend
```

These values should match the backend configuration.

## Emergency Flow

1. **Check-in Alert Triggered** (Heart rate monitor not detected for 45+ seconds)
   - CheckInAlertView shows with ringer & flash

2. **60-Second Window**
   - User must tap "OK" + authenticate with Face ID/Passcode
   - If successful: Timer resets, normal monitoring resumes
   - If failed/timeout: Proceed to step 3

3. **Automatic Location Submission**
   - Real-time GPS coordinates sent to backend via GET request
   - Location saved with timestamp to [user].csv
   - Backend returns confirmation + map view

4. **Location Tracking**
   - Emergency contacts can view live location at backend dashboard
   - All historical locations with timestamps accessible
   - One-click Apple Maps integration

## Backend URLs Reference

**Emergency Location Submission** (Automatic):
```
GET https://ronvoy.com/index.php?location=37.7749,-122.4194&user=Sahaya&token=1234
```

**View Dashboard**:
```
https://ronvoy.com/index.php
```

**View User History** (with valid credentials):
```
POST https://ronvoy.com/index.php
- user: Sahaya
- token: 1234
```

## Security Considerations

### Token Management

- Change `VALID_TOKENS` regularly
- Use strong, random tokens (avoid simple patterns like "1234")
- Never commit tokens to public repositories

**Production Recommendation**:
```php
define('VALID_TOKENS', [
    'token_' . hash('sha256', 'secure-random-string-1'),
    'token_' . hash('sha256', 'secure-random-string-2'),
]);
```

### HTTPS

Always use HTTPS to encrypt location data in transit:
- Enable SSL/TLS on your web server
- Update app backend URL to use `https://`

### Data Privacy

- Location data stored locally on server
- CSV files contain sensitive GPS coordinates
- Restrict file access to authorized users only
- Consider encryption for sensitive deployments

### Rate Limiting

For production, add rate limiting to prevent abuse:

```php
// Simple rate limiting example
$clientIP = $_SERVER['REMOTE_ADDR'];
$rateLimitKey = 'ratelimit_' . md5($clientIP);

// Check if client has exceeded limit (10 requests per minute)
if (/* check rate limit */) {
    http_response_code(429); // Too Many Requests
    die('Rate limit exceeded');
}
```

## Troubleshooting

### Location Not Appearing

1. **Check backend URL**: Verify `backendURL` in SafetyManager.swift
2. **Check token**: Ensure token matches `VALID_TOKENS` in index.php
3. **Check network**: Ensure device has internet connectivity
4. **Check logs**: Look for errors in console (search for "SafetyManager")

### Missing Location History

1. **Check file permissions**: Verify `tapsafe_data` directory is writable
2. **Check user name**: Ensure spelling matches exactly (case-sensitive)
3. **Check CSV file**: Look in `tapsafe_data/[user].csv` for entries

### Invalid Token Errors

1. **Verify token match**: Token in app must match `VALID_TOKENS`
2. **Check for typos**: Tokens are case-sensitive
3. **Restart app**: Clear app cache if token recently changed

## Example Deployment

### Upload to Server

```bash
# 1. Connect to server via SFTP
sftp user@ronvoy.com

# 2. Navigate to web root
cd /var/www/html/

# 3. Upload index.php
put index.php

# 4. Create data directory
mkdir tapsafe_data
chmod 755 tapsafe_data

# 5. Verify upload
ls -la index.php
ls -la tapsafe_data/
```

### Test Endpoint

```bash
# Test from command line
curl "https://ronvoy.com/index.php?location=37.7749,-122.4194&user=TestUser&token=1234"

# Expected response: HTML page showing location on Apple Maps
```

## API Response Examples

### Success - Location Received (GET)

```
HTTP/1.1 200 OK
Content-Type: text/html; charset=UTF-8

[HTML page showing]:
- ✅ Status: Location Received
- User: Sahaya
- Coordinates: 37.7749, -122.4194
- Time: 2026-02-22 14:30:45
- Apple Maps iframe with location
```

### Success - View History (POST)

```
HTTP/1.1 200 OK
Content-Type: text/html; charset=UTF-8

[HTML page showing]:
- Table of all locations with timestamps
- Each row: timestamp | coordinates | "View Map" link
- Latest location displayed in Apple Maps iframe
```

### Error - Invalid Token or Parameters

```
HTTP/1.1 404 Not Found
Content-Type: text/html; charset=UTF-8

[HTML page showing]:
- Error Code: 404
- Message: Invalid request parameters or unauthorized access
- Back to Login link
```

## Monitoring

### Recommended Monitoring Tasks

1. **Regular Backup**
   ```bash
   # Daily backup of location data
   tar -czf tapsafe_backup_$(date +%Y%m%d).tar.gz tapsafe_data/
   ```

2. **Log Review**
   - Monitor web server access logs for unusual patterns
   - Check for repeated failed token attempts (potential attacks)

3. **Disk Space**
   - Monitor `tapsafe_data` directory size
   - Implement data retention policy (e.g., delete 30-day-old records)

## Future Enhancements

Possible improvements for future versions:

1. **Database Integration** - Replace CSV with MySQL/PostgreSQL
2. **Real-time Notifications** - WebSocket updates for live tracking
3. **Geofence Alerts** - Alert when user leaves designated area
4. **Multi-User Support** - Better user management and permissions
5. **Analytics Dashboard** - Usage statistics and reports
6. **Mobile App Integration** - View tracking in separate app
7. **SMS Forwarding** - Auto-forward location via SMS gateway
8. **Email Alerts** - Auto-email location to emergency contacts

## Support

For issues or questions:

1. Check the logs in SafetyManager.swift console output
2. Verify all configuration matches
3. Test the backend URL directly in browser
4. Check server error logs (`/var/log/apache2/error.log` or equivalent)

## License

TapSafe - Open source emergency safety application
