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

// Configuration
$upload_dir = 'apps/';
$max_file_size = 200 * 1024 * 1024; // 200MB for Windows apps
$allowed_extensions = ['apk', 'zip', 'exe', 'msi'];

// Create upload directory if it doesn't exist
if (!is_dir($upload_dir)) {
    mkdir($upload_dir, 0755, true);
}

// Check if file was uploaded
if (!isset($_FILES['app_file']) || $_FILES['app_file']['error'] !== UPLOAD_ERR_OK) {
    http_response_code(400);
    echo json_encode(['success' => false, 'message' => 'No file uploaded or upload error']);
    exit();
}

$file = $_FILES['app_file'];
$original_name = $file['name'];
$file_size = $file['size'];
$file_tmp = $file['tmp_name'];

// Check file size
if ($file_size > $max_file_size) {
    http_response_code(400);
    echo json_encode(['success' => false, 'message' => 'File too large. Maximum size: 200MB']);
    exit();
}

// Check file extension
$file_extension = strtolower(pathinfo($original_name, PATHINFO_EXTENSION));
if (!in_array($file_extension, $allowed_extensions)) {
    http_response_code(400);
    echo json_encode(['success' => false, 'message' => 'Invalid file type. Only APK, ZIP, EXE, and MSI files are allowed']);
    exit();
}

// Generate unique filename
$version = $_POST['version'] ?? date('Y-m-d_H-i-s');
$platform = $_POST['platform'] ?? ($file_extension === 'apk' ? 'android' : 'windows');
$new_filename = "estarcommande-{$platform}-v{$version}.{$file_extension}";
$upload_path = $upload_dir . $new_filename;

// Move uploaded file
if (move_uploaded_file($file_tmp, $upload_path)) {
    // Generate the download URL
    $domain = $_SERVER['HTTP_HOST'];
    $protocol = isset($_SERVER['HTTPS']) && $_SERVER['HTTPS'] === 'on' ? 'https' : 'http';
    $download_url = "$protocol://$domain/" . dirname($_SERVER['REQUEST_URI']) . "/$upload_path";
    
    // Log the upload
    $log_entry = date('Y-m-d H:i:s') . " - File uploaded: $new_filename (Size: " . formatBytes($file_size) . ")\n";
    file_put_contents('uploads.log', $log_entry, FILE_APPEND | LOCK_EX);
    
    echo json_encode([
        'success' => true,
        'message' => 'File uploaded successfully',
        'filename' => $new_filename,
        'download_url' => $download_url,
        'file_size' => formatBytes($file_size)
    ]);
} else {
    http_response_code(500);
    echo json_encode(['success' => false, 'message' => 'Failed to save uploaded file']);
}

function formatBytes($bytes, $precision = 2) {
    $units = array('B', 'KB', 'MB', 'GB', 'TB');
    
    for ($i = 0; $bytes > 1024; $i++) {
        $bytes /= 1024;
    }
    
    return round($bytes, $precision) . ' ' . $units[$i];
}
?>
