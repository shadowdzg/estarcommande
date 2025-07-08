<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

// Handle preflight requests
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

// Only allow POST requests
if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo json_encode(['success' => false, 'message' => 'Method not allowed']);
    exit();
}

// Get JSON input
$input = file_get_contents('php://input');
$data = json_decode($input, true);

if (!$data) {
    http_response_code(400);
    echo json_encode(['success' => false, 'message' => 'Invalid JSON data']);
    exit();
}

// Validate required fields
$required_fields = ['android', 'windows'];
foreach ($required_fields as $field) {
    if (!isset($data[$field])) {
        http_response_code(400);
        echo json_encode(['success' => false, 'message' => "Missing required field: $field"]);
        exit();
    }
}

// Validate platform data
foreach (['android', 'windows'] as $platform) {
    $platform_data = $data[$platform];
    $required_platform_fields = ['version', 'buildNumber', 'downloadUrl'];
    
    foreach ($required_platform_fields as $field) {
        if (!isset($platform_data[$field]) || empty($platform_data[$field])) {
            http_response_code(400);
            echo json_encode(['success' => false, 'message' => "Missing required field: $platform.$field"]);
            exit();
        }
    }
    
    // Validate version format
    if (!preg_match('/^\d+\.\d+\.\d+$/', $platform_data['version'])) {
        http_response_code(400);
        echo json_encode(['success' => false, 'message' => "Invalid version format for $platform. Use format: X.Y.Z"]);
        exit();
    }
    
    // Validate build number
    if (!is_numeric($platform_data['buildNumber']) || $platform_data['buildNumber'] < 1) {
        http_response_code(400);
        echo json_encode(['success' => false, 'message' => "Invalid build number for $platform"]);
        exit();
    }
    
    // Validate URL
    if (!filter_var($platform_data['downloadUrl'], FILTER_VALIDATE_URL)) {
        http_response_code(400);
        echo json_encode(['success' => false, 'message' => "Invalid download URL for $platform"]);
        exit();
    }
}

// Prepare the configuration
$config = [
    'android' => [
        'version' => $data['android']['version'],
        'buildNumber' => intval($data['android']['buildNumber']),
        'downloadUrl' => $data['android']['downloadUrl'],
        'changelog' => $data['android']['changelog'] ?? [],
        'isForceUpdate' => $data['android']['isForceUpdate'] ?? false,
        'isCriticalUpdate' => $data['android']['isCriticalUpdate'] ?? false,
        'minSupportedVersion' => '1.0.0'
    ],
    'windows' => [
        'version' => $data['windows']['version'],
        'buildNumber' => intval($data['windows']['buildNumber']),
        'downloadUrl' => $data['windows']['downloadUrl'],
        'changelog' => $data['windows']['changelog'] ?? [],
        'isForceUpdate' => $data['windows']['isForceUpdate'] ?? false,
        'isCriticalUpdate' => $data['windows']['isCriticalUpdate'] ?? false,
        'minSupportedVersion' => '1.0.0'
    ]
];

// Create backup of current version.php
$version_file = 'version.php';
$backup_file = 'version_backup_' . date('Y-m-d_H-i-s') . '.php';

if (file_exists($version_file)) {
    copy($version_file, $backup_file);
}

// Generate new version.php content
$php_content = "<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

// Handle preflight requests
if (\$_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

// Configuration
\$config = " . var_export($config, true) . ";

// Get parameters
\$platform = \$_GET['platform'] ?? 'android';
\$currentVersion = \$_GET['currentVersion'] ?? '1.0.0';
\$buildNumber = intval(\$_GET['buildNumber'] ?? 1);

// Validate platform
if (!isset(\$config[\$platform])) {
    http_response_code(400);
    echo json_encode(['error' => 'Platform not supported']);
    exit();
}

\$latest = \$config[\$platform];

// Check if update is available
\$hasUpdate = false;
\$isForceUpdate = false;
\$isCriticalUpdate = false;

// Compare versions
if (version_compare(\$latest['version'], \$currentVersion, '>')) {
    \$hasUpdate = true;
} elseif (version_compare(\$latest['version'], \$currentVersion, '==') && \$latest['buildNumber'] > \$buildNumber) {
    \$hasUpdate = true;
}

// Check if current version is below minimum supported
if (version_compare(\$currentVersion, \$latest['minSupportedVersion'], '<')) {
    \$hasUpdate = true;
    \$isForceUpdate = true;
    \$isCriticalUpdate = true;
} else {
    \$isForceUpdate = \$latest['isForceUpdate'];
    \$isCriticalUpdate = \$latest['isCriticalUpdate'];
}

// Prepare response
\$response = [
    'hasUpdate' => \$hasUpdate,
    'isForceUpdate' => \$isForceUpdate,
    'isCriticalUpdate' => \$isCriticalUpdate,
    'current' => [
        'version' => \$currentVersion,
        'buildNumber' => \$buildNumber
    ],
    'latest' => \$latest
];

// Log the request (optional)
\$logFile = 'update_checks.log';
\$logEntry = date('Y-m-d H:i:s') . \" - Platform: \$platform, Current: \$currentVersion+\$buildNumber, Has Update: \" . (\$hasUpdate ? 'Yes' : 'No') . \"\\n\";
file_put_contents(\$logFile, \$logEntry, FILE_APPEND | LOCK_EX);

echo json_encode(\$response, JSON_PRETTY_PRINT);
?>";

// Write new version.php
if (file_put_contents($version_file, $php_content) !== false) {
    // Log the update
    $log_entry = date('Y-m-d H:i:s') . " - Version updated by admin panel\n";
    $log_entry .= "Android: " . $config['android']['version'] . "+" . $config['android']['buildNumber'] . "\n";
    $log_entry .= "Windows: " . $config['windows']['version'] . "+" . $config['windows']['buildNumber'] . "\n";
    $log_entry .= "---\n";
    
    file_put_contents('admin_updates.log', $log_entry, FILE_APPEND | LOCK_EX);
    
    echo json_encode([
        'success' => true,
        'message' => 'Versions updated successfully',
        'backup_created' => $backup_file
    ]);
} else {
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Failed to write version file'
    ]);
}
?>
