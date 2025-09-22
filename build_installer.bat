@echo off
echo ========================================
echo EST STAR Commande Installer Builder
echo ========================================
set /p version="Enter version (e.g., 1.0.1): "
echo.
echo Building Flutter Windows app...


echo Creating dist folder...
if not exist "dist" mkdir "dist"
echo Dist folder created/exists
echo.

echo Creating installer for version %version%...
set APP_VERSION=%version%
echo APP_VERSION set to: %APP_VERSION%
echo.

echo Checking required files...
echo Current directory: %CD%
echo.

echo Checking for Flutter executable...
if not exist "build\windows\x64\runner\Release\est_star_commande.exe" (
    echo ERROR: Flutter build not found! Make sure Flutter build completed successfully.
    echo Looking for: build\windows\x64\runner\Release\estarcommande.exe
    echo.
    echo Current directory contents:
    dir build\windows\x64\runner\Release\ 2>nul || echo Release folder not found
    echo.
    echo Let's check what's in the build folder:
    dir build\ 2>nul || echo Build folder not found
    echo.
    echo Let's check the Release folder structure:
    dir build\windows\ 2>nul || echo Windows folder not found
    dir build\windows\x64\ 2>nul || echo x64 folder not found
    dir build\windows\x64\runner\ 2>nul || echo Runner folder not found
    pause
    exit /b 1
)

echo ✓ Flutter executable found!
echo.

echo Checking for installer.iss...
if not exist "installer.iss" (
    echo ERROR: installer.iss not found!
    echo Current directory: %CD%
    echo Files in current directory:
    dir *.iss 2>nul || echo No .iss files found
    pause
    exit /b 1
)

echo ✓ All required files found!
echo.

echo Files check passed. Running Inno Setup...

REM Check different possible Inno Setup locations
if exist "C:\Program Files (x86)\Inno Setup 6\ISCC.exe" (
    echo Using Inno Setup 6 (x86)
    "C:\Program Files (x86)\Inno Setup 6\ISCC.exe" installer.iss
) else if exist "C:\Program Files\Inno Setup 6\ISCC.exe" (
    echo Using Inno Setup 6 (x64)
    "C:\Program Files\Inno Setup 6\ISCC.exe" installer.iss
) else if exist "C:\Program Files (x86)\Inno Setup 5\ISCC.exe" (
    echo Using Inno Setup 5 (x86)
    "C:\Program Files (x86)\Inno Setup 5\ISCC.exe" installer.iss
) else (
    echo ERROR: Inno Setup not found! Please install Inno Setup or update the path.
    echo Download from: https://jrsoftware.org/isinfo.php
    pause
    exit /b 1
)

echo.
echo Inno Setup finished with exit code: %ERRORLEVEL%

if %ERRORLEVEL% == 0 (
    echo.
    echo SUCCESS: Installer should be created: dist\EST_STAR_Commande_Setup_v%version%.exe
    if exist "dist\EST_STAR_Commande_Setup_v%version%.exe" (
        echo ✓ Installer file confirmed!
        dir "dist\EST_STAR_Commande_Setup_v%version%.exe"
    ) else (
        echo ✗ Installer file NOT found in dist folder!
        echo Checking dist folder contents:
        dir dist
    )
) else (
    echo.
    echo ERROR: Failed to create installer. Check the output above for details.
)

echo.
echo Press any key to exit...
pause
