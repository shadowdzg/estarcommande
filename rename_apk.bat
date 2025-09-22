@echo off
echo ========================================
echo EST STAR COMMANDE - APK COPY AND RENAME
echo ========================================

:: Create dist folder
if not exist "dist" mkdir dist

:: Extract version from pubspec.yaml
for /f "tokens=2 delims=: " %%a in ('findstr "^version:" pubspec.yaml') do set VERSION=%%a
for /f "tokens=1 delims=+" %%a in ("%VERSION%") do set VERSION=%%a
set VERSION=%VERSION: =%

echo Version: %VERSION%

:: Check if APK exists
if not exist "build\app\outputs\flutter-apk\app-release.apk" (
    echo ERROR: APK not found! Please build the APK first.
    echo Run: flutter build apk --release
    pause
    exit /b 1
)

:: Generate simple timestamp
set TIMESTAMP=%date:~6,4%-%date:~3,2%-%date:~0,2%_%time:~0,2%-%time:~3,2%
set TIMESTAMP=%TIMESTAMP: =0%

:: Create filename
set APK_NAME=EstStarCommande_v%VERSION%_%TIMESTAMP%.apk

:: Copy APK
echo.
echo Copying APK to dist folder...
echo Source: build\app\outputs\flutter-apk\app-release.apk
echo Destination: dist\%APK_NAME%

copy "build\app\outputs\flutter-apk\app-release.apk" "dist\%APK_NAME%"

if exist "dist\%APK_NAME%" (
    echo.
    echo SUCCESS!
    echo APK saved as: %APK_NAME%
    echo Location: dist\%APK_NAME%
    echo.
    
    :: Show file size
    for %%A in ("dist\%APK_NAME%") do set APK_SIZE=%%~zA
    set /a APK_SIZE_MB=%APK_SIZE%/1024/1024
    echo Size: %APK_SIZE_MB% MB
    
    :: Ask to open folder
    set /p OPEN=Open dist folder? (y/n): 
    if /i "%OPEN%"=="y" start explorer "dist"
) else (
    echo ERROR: Failed to copy APK!
)

pause
