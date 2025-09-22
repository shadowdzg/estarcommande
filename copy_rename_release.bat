@echo off
setlocal

echo ====================================
echo    APK Release Copy and Rename
echo ====================================
echo.

:: Set the source APK path (default Flutter release build location)
set "SOURCE_APK=build\app\outputs\flutter-apk\app-release.apk"

:: Check if source APK exists
if not exist "%SOURCE_APK%" (
    echo ERROR: Release APK not found at: %SOURCE_APK%
    echo.
    echo Please build the release APK first using:
    echo flutter build apk --release
    echo.
    pause
    exit /b 1
)

:: Create dist folder if it doesn't exist
if not exist "dist" (
    echo Creating dist folder...
    mkdir dist
)

:: Get current date and time for default version
for /f "tokens=2 delims==" %%a in ('wmic OS Get localdatetime /value') do set "dt=%%a"
set "YYYY=%dt:~0,4%"
set "MM=%dt:~4,2%"
set "DD=%dt:~6,2%"
set "HH=%dt:~8,2%"
set "MIN=%dt:~10,2%"
set "DEFAULT_VERSION=v%YYYY%.%MM%.%DD%_%HH%%MIN%"

:: Ask user for version name
echo Current APK found: %SOURCE_APK%
echo Default version: %DEFAULT_VERSION%
echo.
set /p "VERSION=Enter version name (or press Enter for default): "

:: Use default if no input provided
if "%VERSION%"=="" set "VERSION=%DEFAULT_VERSION%"

:: Set destination filename
set "DEST_APK=dist\estarcommande_%VERSION%.apk"

:: Copy and rename the APK
echo.
echo Copying APK...
echo From: %SOURCE_APK%
echo To:   %DEST_APK%
echo.

copy "%SOURCE_APK%" "%DEST_APK%"

if %ERRORLEVEL% EQU 0 (
    echo SUCCESS: APK copied and renamed successfully!
    echo.
    echo File location: %DEST_APK%
    
    :: Get file size
    for %%A in ("%DEST_APK%") do (
        set "SIZE=%%~zA"
        set /a "SIZE_MB=!SIZE! / 1024 / 1024"
    )
    echo File size: !SIZE_MB! MB
    
    :: Open dist folder
    echo.
    set /p "OPEN_FOLDER=Open dist folder? (y/n): "
    if /i "!OPEN_FOLDER!"=="y" (
        explorer dist
    )
) else (
    echo ERROR: Failed to copy APK file.
)

echo.
pause
