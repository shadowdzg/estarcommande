# EST STAR Commande - Custom Update Server Setup (cPanel)

## 📋 Files to Upload to Your cPanel

Upload these files to your cPanel file manager in a subdirectory (e.g., `/public_html/app-updates/`):

1. **version.php** - Main API endpoint for version checking
2. **admin.html** - Admin panel for managing versions
3. **update_version.php** - Backend script for updating versions
4. **upload.php** - File upload handler for APK/IPA files

## 🔧 cPanel Setup Instructions

### Step 1: Upload Files
1. Log into your cPanel
2. Go to **File Manager**
3. Navigate to `public_html` (or your domain's root directory)
4. Create a new folder: `app-updates`
5. Upload all PHP and HTML files to this folder

### Step 2: Set Permissions
1. Right-click on the `app-updates` folder
2. Select **Change Permissions**
3. Set to **755** (rwxr-xr-x)
4. Apply to all files in the folder

### Step 3: Test the Setup
1. Visit: `https://your-domain.com/app-updates/version.php`
2. You should see a JSON response with version information
3. Visit: `https://your-domain.com/app-updates/admin.html`
4. You should see the admin panel

## 📱 Flutter App Configuration

Update your Flutter app's `update_service.dart` to use your server:

```dart
// Replace this URL with your actual domain
const serverUrl = 'https://your-domain.com/app-updates/version.php';
```

## 🚀 How to Use

### For Developers:
1. Build your APK/IPA files
2. Upload them to the `apps/` folder (will be created automatically)
3. Use the admin panel to update version information
4. Test the update flow in your app

### For Users:
1. The app will automatically check for updates
2. Users will be prompted to download and install new versions
3. Updates can be forced or optional based on your settings

## 🔒 Security Considerations

### Recommended Security Measures:
1. **Password protect the admin panel**:
   ```php
   // Add to the top of admin.html
   <?php
   session_start();
   if (!isset($_SESSION['admin_logged_in'])) {
       // Show login form
   }
   ?>
   ```

2. **Add IP restrictions**:
   ```php
   // Add to update_version.php
   $allowed_ips = ['your.ip.address'];
   if (!in_array($_SERVER['REMOTE_ADDR'], $allowed_ips)) {
       http_response_code(403);
       exit('Access denied');
   }
   ```

3. **Use HTTPS**: Always use HTTPS for your update server

## 📊 Monitoring

### Log Files Created:
- `update_checks.log` - Logs all version check requests
- `admin_updates.log` - Logs admin panel updates
- `uploads.log` - Logs file uploads

### Monitor Usage:
```bash
# View recent update checks
tail -f update_checks.log

# View admin actions
tail -f admin_updates.log
```

## 🛠 Troubleshooting

### Common Issues:

1. **403 Forbidden Error**:
   - Check file permissions (should be 755)
   - Ensure cPanel allows PHP execution

2. **JSON Parse Error**:
   - Check PHP error logs in cPanel
   - Verify file uploads completed successfully

3. **Large File Upload Issues**:
   - Increase `upload_max_filesize` in PHP settings
   - Increase `post_max_size` in PHP settings
   - Check cPanel PHP configuration

### PHP Settings to Check:
```ini
upload_max_filesize = 100M
post_max_size = 100M
max_execution_time = 300
memory_limit = 256M
```

## 📝 Version Format

Use semantic versioning: `MAJOR.MINOR.PATCH`
- Example: `1.0.0`, `1.0.1`, `1.1.0`
- Build numbers should increment with each release

## 🔄 Update Flow

1. **Check for Updates**: App calls `version.php`
2. **Compare Versions**: Server compares current vs latest
3. **Show Dialog**: App displays update prompt if needed
4. **Download**: User downloads new version
5. **Install**: User installs manually (Android) or through enterprise distribution (iOS)

## 🌐 Testing

### Test URLs:
- Version check: `https://your-domain.com/app-updates/version.php?platform=android&currentVersion=1.0.0&buildNumber=1`
- Admin panel: `https://your-domain.com/app-updates/admin.html`

### Test with curl:
```bash
curl "https://your-domain.com/app-updates/version.php?platform=android&currentVersion=1.0.0&buildNumber=1"
```

## 📱 Integration in Flutter App

Add this to your main app (e.g., in `main.dart` or `entry_point.dart`):

```dart
// Check for updates on app start
void initState() {
  super.initState();
  WidgetsBinding.instance.addPostFrameCallback((_) {
    UpdateService.checkForServerUpdate(context);
  });
}

// Manual update check (add to settings/menu)
ElevatedButton(
  onPressed: () => UpdateService.manualUpdateCheck(context),
  child: Text('Check for Updates'),
)
```

## 🎯 Next Steps

1. Upload files to your cPanel
2. Test the version endpoint
3. Update your Flutter app configuration
4. Build and test the update flow
5. Deploy your first update!

## 🆘 Support

If you encounter issues:
1. Check cPanel error logs
2. Verify file permissions
3. Test with simple HTTP requests
4. Check PHP version compatibility (requires PHP 7.4+)
