# 🚀 EST STAR Commande - Custom Update Server Setup (Android & Windows)

## 📋 Quick Start Guide

### 1. Upload to cPanel
1. Log into your cPanel
2. Go to **File Manager**
3. Create folder: `public_html/` (or your domain's root)
4. Upload these files from `c:\estarcommande\server\cpanel\`:
   - `version.php`
   - `admin.html`
   - `update_version.php`
   - `upload.php`

### 2. Update Flutter App
Your app is already configured for: `https://update.eststar.dz/version.php`

### 3. Test Setup
1. Visit: `https://update.eststar.dz/version.php`
2. Should see JSON response
3. Visit: `https://update.eststar.dz/admin.html`
4. Should see admin panel

### 4. Create Your First Update

**For Android:**
1. Build your APK: `flutter build apk --release`
2. Upload APK to your server's `apps/` folder
3. Use admin panel to set Android version info

**For Windows:**
1. Build your Windows app: `flutter build windows --release`
2. Create a ZIP file with the contents of `build/windows/x64/runner/Release/`
3. Upload ZIP to your server's `apps/` folder
4. Use admin panel to set Windows version info
3. Use admin panel to set version info
4. Test in your app

## 🔧 How It Works

### For Users:
- **Android**: App checks for updates → Shows dialog → Downloads APK → User installs manually
- **Windows**: App checks for updates → Shows dialog → Downloads ZIP/installer → User extracts/runs

### For Admins:
- Use admin panel to manage both Android and Windows versions
- Upload APK files for Android
- Upload ZIP/EXE/MSI files for Windows
- Set version numbers and changelogs independently
- Force updates when needed for either platform

## 🎯 Next Steps

1. **Replace your domain** in update_service.dart
2. **Upload server files** to your cPanel
3. **Build and test** your app
4. **Create your first update** using the admin panel

## 📱 Testing

Build and test your app:
```bash
flutter build apk --release
flutter install
```

The app will now check for updates automatically and show the update dialog when available.

## 🛡️ Security Notes

- Consider password protecting the admin panel
- Use HTTPS for all connections
- Limit file upload sizes
- Monitor logs for unusual activity

Your custom update system is now ready! 🎉
