<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

// Handle preflight requests
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

// Configuration
$config = [
    'android' => [
        'version' => '1.0.1',
        'buildNumber' => 2,
        'downloadUrl' => 'https://update.eststar.dz/apps/estarcommande-android-v1.0.1.apk',
        'changelog' => [
            'Nouvelles fonctionnalités de commande',
            'Amélioration des performances',
            'Corrections de bugs'
        ],
        'isForceUpdate' => false,
        'isCriticalUpdate' => false,
        'minSupportedVersion' => '1.0.0'
    ],
    'windows' => [
        'version' => '1.0.1',
        'buildNumber' => 2,
        'downloadUrl' => 'https://update.eststar.dz/apps/estarcommande-windows-v1.0.1.zip',
        'changelog' => [
            'Nouvelles fonctionnalités de commande',
            'Amélioration des performances',
            'Corrections de bugs'
        ],
        'isForceUpdate' => false,
        'isCriticalUpdate' => false,
        'minSupportedVersion' => '1.0.0'
    ]
];

// Get parameters
$platform = $_GET['platform'] ?? 'android';
$currentVersion = $_GET['currentVersion'] ?? '1.0.0';
$buildNumber = intval($_GET['buildNumber'] ?? 1);

// Validate platform
if (!isset($config[$platform])) {
    http_response_code(400);
    echo json_encode(['error' => 'Platform not supported. Only Android and Windows are supported.']);
    exit();
}

$latest = $config[$platform];

// Check if update is available
$hasUpdate = false;
$isForceUpdate = false;
$isCriticalUpdate = false;

// Compare versions
if (version_compare($latest['version'], $currentVersion, '>')) {
    $hasUpdate = true;
} elseif (version_compare($latest['version'], $currentVersion, '==') && $latest['buildNumber'] > $buildNumber) {
    $hasUpdate = true;
}

// Check if current version is below minimum supported
if (version_compare($currentVersion, $latest['minSupportedVersion'], '<')) {
    $hasUpdate = true;
    $isForceUpdate = true;
    $isCriticalUpdate = true;
} else {
    $isForceUpdate = $latest['isForceUpdate'];
    $isCriticalUpdate = $latest['isCriticalUpdate'];
}

// Prepare response
$response = [
    'hasUpdate' => $hasUpdate,
    'isForceUpdate' => $isForceUpdate,
    'isCriticalUpdate' => $isCriticalUpdate,
    'current' => [
        'version' => $currentVersion,
        'buildNumber' => $buildNumber
    ],
    'latest' => $latest
];

// Log the request (optional)
$logFile = 'update_checks.log';
$logEntry = date('Y-m-d H:i:s') . " - Platform: $platform, Current: $currentVersion+$buildNumber, Has Update: " . ($hasUpdate ? 'Yes' : 'No') . "\n";
file_put_contents($logFile, $logEntry, FILE_APPEND | LOCK_EX);

echo json_encode($response, JSON_PRETTY_PRINT);
?>
