<?php
/**
 * TapSafe Emergency Locator Backend
 * Single-page PHP application for emergency contact tracking
 * 
 * Features:
 * - GET: Submit emergency location with token validation
 * - POST: Authentication and user history retrieval
 * - Responsive mobile-friendly UI
 * - Apple Maps integration
 */

// Configuration
define('DATA_DIR', __DIR__ . '/tapsafe_data');
define('VALID_TOKENS', ['1234', '5678', 'demo-token']); // Add valid tokens here
define('HASH_TOKEN', true); // Set to true for production

// Ensure data directory exists
if (!is_dir(DATA_DIR)) {
    mkdir(DATA_DIR, 0755, true);
}

// Helper function to validate token
function validateToken($token) {
    return in_array($token, VALID_TOKENS);
}

// Helper function to get CSV file path
function getUserCSVPath($user) {
    $sanitized = preg_replace('/[^a-zA-Z0-9_-]/', '', $user);
    return DATA_DIR . '/' . $sanitized . '.csv';
}

// Helper function to log location
function logLocation($user, $lat, $lon) {
    $csvPath = getUserCSVPath($user);
    $timestamp = date('Y-m-d H:i:s');
    
    // Create file if not exists
    if (!file_exists($csvPath)) {
        file_put_contents($csvPath, "timestamp,latitude,longitude\n");
    }
    
    // Append new location
    $line = "$timestamp,$lat,$lon\n";
    file_put_contents($csvPath, $line, FILE_APPEND);
    
    return true;
}

// Helper function to get user history
function getUserHistory($user) {
    $csvPath = getUserCSVPath($user);
    $history = [];
    
    if (file_exists($csvPath)) {
        $lines = file($csvPath, FILE_IGNORE_NEW_LINES);
        foreach (array_slice($lines, 1) as $line) { // Skip header
            if (trim($line)) {
                list($timestamp, $lat, $lon) = explode(',', $line);
                $history[] = [
                    'timestamp' => $timestamp,
                    'latitude' => $lat,
                    'longitude' => $lon,
                    'mapsUrl' => "https://maps.apple.com/?q=$lat,$lon"
                ];
            }
        }
    }
    
    return array_reverse($history); // Most recent first
}

// Determine request method and parameters
$method = $_SERVER['REQUEST_METHOD'];
$user = isset($_REQUEST['user']) ? trim($_REQUEST['user']) : '';
$token = isset($_REQUEST['token']) ? trim($_REQUEST['token']) : '';
$location = isset($_REQUEST['location']) ? trim($_REQUEST['location']) : '';

// Parse location coordinates
$lat = null;
$lon = null;
if ($location) {
    $coords = explode(',', $location);
    if (count($coords) === 2) {
        $lat = floatval($coords[0]);
        $lon = floatval($coords[1]);
    }
}

// Route handling
$isValidRequest = false;
$responseData = [];

if ($method === 'GET' && $user && $token && $lat && $lon) {
    // GET: Emergency location submission
    if (validateToken($token)) {
        logLocation($user, $lat, $lon);
        $isValidRequest = true;
        $responseData = [
            'type' => 'location_received',
            'user' => $user,
            'lat' => $lat,
            'lon' => $lon,
            'timestamp' => date('Y-m-d H:i:s')
        ];
    }
} elseif ($method === 'POST' && $user && $token) {
    // POST: Authentication and history retrieval
    if (validateToken($token)) {
        $isValidRequest = true;
        $responseData = [
            'type' => 'history',
            'user' => $user,
            'history' => getUserHistory($user)
        ];
    }
} elseif ($method === 'GET' && !$user && !$token && !$location) {
    // GET: Show login form
    $isValidRequest = true;
    $responseData = ['type' => 'login_form'];
}

?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>TapSafe Emergency Locator</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }

        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
            padding: 16px;
        }

        .container {
            width: 100%;
            max-width: 600px;
            background: white;
            border-radius: 16px;
            box-shadow: 0 20px 60px rgba(0, 0, 0, 0.3);
            overflow: hidden;
        }

        .header {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 24px 16px;
            text-align: center;
        }

        .header h1 {
            font-size: 28px;
            margin-bottom: 8px;
        }

        .header p {
            font-size: 14px;
            opacity: 0.9;
        }

        .content {
            padding: 24px 16px;
        }

        /* Login Form Styles */
        .form-group {
            margin-bottom: 16px;
        }

        label {
            display: block;
            margin-bottom: 8px;
            font-weight: 500;
            color: #333;
        }

        input[type="text"],
        input[type="password"] {
            width: 100%;
            padding: 12px;
            border: 2px solid #e0e0e0;
            border-radius: 8px;
            font-size: 16px;
            transition: border-color 0.3s;
        }

        input[type="text"]:focus,
        input[type="password"]:focus {
            outline: none;
            border-color: #667eea;
        }

        button {
            width: 100%;
            padding: 12px;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            border: none;
            border-radius: 8px;
            font-size: 16px;
            font-weight: 600;
            cursor: pointer;
            transition: transform 0.2s, box-shadow 0.2s;
        }

        button:active {
            transform: scale(0.98);
        }

        button:hover {
            box-shadow: 0 10px 20px rgba(102, 126, 234, 0.3);
        }

        /* Location Received Styles */
        .status-card {
            background: #f0f8ff;
            border: 2px solid #667eea;
            border-radius: 8px;
            padding: 16px;
            margin-bottom: 16px;
            text-align: center;
        }

        .status-card.success {
            background: #f0fdf4;
            border-color: #22c55e;
        }

        .status-icon {
            font-size: 48px;
            margin-bottom: 12px;
        }

        .status-text {
            font-size: 18px;
            font-weight: 600;
            color: #333;
            margin-bottom: 4px;
        }

        .status-meta {
            font-size: 14px;
            color: #666;
        }

        /* Maps Container */
        .maps-container {
            margin: 24px 0;
            border-radius: 8px;
            overflow: hidden;
            box-shadow: 0 4px 12px rgba(0, 0, 0, 0.1);
        }

        iframe {
            width: 100%;
            height: 400px;
            border: none;
        }

        /* History Table Styles */
        .history-section {
            margin-top: 24px;
        }

        .history-title {
            font-size: 20px;
            font-weight: 600;
            color: #333;
            margin-bottom: 12px;
        }

        .history-table {
            width: 100%;
            border-collapse: collapse;
            margin-bottom: 16px;
        }

        .history-table th {
            background: #f5f5f5;
            padding: 12px;
            text-align: left;
            font-weight: 600;
            color: #333;
            border-bottom: 2px solid #e0e0e0;
        }

        .history-table td {
            padding: 12px;
            border-bottom: 1px solid #e0e0e0;
        }

        .history-table tr:hover {
            background: #f9f9f9;
        }

        .location-link {
            color: #667eea;
            text-decoration: none;
            font-weight: 500;
        }

        .location-link:hover {
            text-decoration: underline;
        }

        .no-history {
            padding: 24px;
            text-align: center;
            color: #999;
            background: #f9f9f9;
            border-radius: 8px;
        }

        /* Error Styles */
        .error-page {
            text-align: center;
            padding: 40px 16px;
        }

        .error-code {
            font-size: 72px;
            font-weight: bold;
            color: #667eea;
            margin-bottom: 12px;
        }

        .error-title {
            font-size: 24px;
            font-weight: 600;
            color: #333;
            margin-bottom: 8px;
        }

        .error-message {
            font-size: 16px;
            color: #666;
            margin-bottom: 24px;
        }

        .back-link {
            display: inline-block;
            color: #667eea;
            text-decoration: none;
            font-weight: 600;
        }

        .back-link:hover {
            text-decoration: underline;
        }

        /* Responsive Design */
        @media (max-width: 480px) {
            .header h1 {
                font-size: 24px;
            }

            .content {
                padding: 16px;
            }

            .history-table {
                font-size: 14px;
            }

            .history-table th,
            .history-table td {
                padding: 8px;
            }

            iframe {
                height: 300px;
            }
        }

        /* Loading Animation */
        .spinner {
            display: inline-block;
            width: 20px;
            height: 20px;
            border: 3px solid #f0f0f0;
            border-top-color: #667eea;
            border-radius: 50%;
            animation: spin 0.6s linear infinite;
        }

        @keyframes spin {
            to { transform: rotate(360deg); }
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🚨 TapSafe</h1>
            <p>Emergency Location Tracker</p>
        </div>

        <div class="content">
            <?php
            // Route to appropriate view
            if (!$isValidRequest) {
                // 404 or Invalid Request
                ?>
                <div class="error-page">
                    <div class="error-code">404</div>
                    <div class="error-title">Not Found</div>
                    <div class="error-message">
                        Invalid request parameters or unauthorized access.
                    </div>
                    <a href="<?php echo htmlspecialchars($_SERVER['PHP_SELF']); ?>" class="back-link">← Back to Login</a>
                </div>
                <?php
            } elseif ($responseData['type'] === 'login_form') {
                // Login Form
                ?>
                <div class="form-group">
                    <label for="username">Username:</label>
                    <input type="text" id="username" name="user" placeholder="Enter your name" required>
                </div>

                <div class="form-group">
                    <label for="token">Access Token:</label>
                    <input type="password" id="token" name="token" placeholder="Enter access token" required>
                </div>

                <button onclick="submitLogin()">View History & Maps</button>

                <script>
                    function submitLogin() {
                        const user = document.getElementById('username').value.trim();
                        const token = document.getElementById('token').value.trim();

                        if (!user || !token) {
                            alert('Please enter both username and token');
                            return;
                        }

                        // Submit POST request
                        const form = document.createElement('form');
                        form.method = 'POST';
                        form.innerHTML = `
                            <input type="hidden" name="user" value="${escapeHtml(user)}">
                            <input type="hidden" name="token" value="${escapeHtml(token)}">
                        `;
                        document.body.appendChild(form);
                        form.submit();
                    }

                    function escapeHtml(text) {
                        const map = {
                            '&': '&amp;',
                            '<': '&lt;',
                            '>': '&gt;',
                            '"': '&quot;',
                            "'": '&#039;'
                        };
                        return text.replace(/[&<>"']/g, m => map[m]);
                    }

                    // Allow Enter key to submit
                    document.addEventListener('keypress', function(e) {
                        if (e.key === 'Enter') {
                            submitLogin();
                        }
                    });
                </script>
                <?php
            } elseif ($responseData['type'] === 'location_received') {
                // Location Received
                $mapsUrl = "https://maps.apple.com/?q=" . $lat . "," . $lon;
                ?>
                <div class="status-card success">
                    <div class="status-icon">✅</div>
                    <div class="status-text">Location Received</div>
                    <div class="status-meta">
                        User: <strong><?php echo htmlspecialchars($user); ?></strong><br>
                        Coordinates: <strong><?php echo $lat . ", " . $lon; ?></strong><br>
                        Time: <strong><?php echo $responseData['timestamp']; ?></strong>
                    </div>
                </div>

                <div class="maps-container">
                    <iframe src="<?php echo htmlspecialchars($mapsUrl); ?>"></iframe>
                </div>

                <div style="text-align: center; color: #666; font-size: 14px;">
                    <p>Emergency location has been recorded and saved.</p>
                </div>
                <?php
            } elseif ($responseData['type'] === 'history') {
                // History View
                $history = $responseData['history'];
                ?>
                <div class="history-section">
                    <div class="history-title">📍 <?php echo htmlspecialchars($user); ?>'s Locations</div>

                    <?php if (empty($history)): ?>
                        <div class="no-history">
                            No location history found for this user.
                        </div>
                    <?php else: ?>
                        <table class="history-table">
                            <thead>
                                <tr>
                                    <th>Timestamp</th>
                                    <th>Location</th>
                                    <th>Action</th>
                                </tr>
                            </thead>
                            <tbody>
                                <?php foreach ($history as $record): ?>
                                    <tr>
                                        <td><?php echo htmlspecialchars($record['timestamp']); ?></td>
                                        <td><?php echo htmlspecialchars($record['latitude']) . ", " . htmlspecialchars($record['longitude']); ?></td>
                                        <td>
                                            <a href="<?php echo htmlspecialchars($record['mapsUrl']); ?>" target="_blank" class="location-link">
                                                View Map →
                                            </a>
                                        </td>
                                    </tr>
                                <?php endforeach; ?>
                            </tbody>
                        </table>

                        <?php if (!empty($history)): ?>
                            <div class="maps-container">
                                <iframe src="<?php echo htmlspecialchars($history[0]['mapsUrl']); ?>"></iframe>
                            </div>
                        <?php endif; ?>
                    <?php endif; ?>
                </div>

                <div style="margin-top: 24px; text-align: center;">
                    <a href="<?php echo htmlspecialchars($_SERVER['PHP_SELF']); ?>" class="back-link">← Back to Login</a>
                </div>
                <?php
            }
            ?>
        </div>
    </div>
</body>
</html>
