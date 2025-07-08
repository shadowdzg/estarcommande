@echo off
echo EST STAR Commande Update Server Setup
echo =======================================
echo.

REM Check if Node.js is installed
where node >nul 2>&1
if %errorlevel% neq 0 (
    echo Node.js is not installed or not in PATH
    echo Please install Node.js from https://nodejs.org/
    echo Make sure to add Node.js to your PATH
    pause
    exit /b 1
)

REM Check Node.js version
echo Checking Node.js version...
node --version

REM Install dependencies
echo.
echo Installing dependencies...
npm install

if %errorlevel% neq 0 (
    echo Failed to install dependencies
    pause
    exit /b 1
)

echo.
echo Setup complete!
echo.
echo To start the server:
echo   npm start
echo.
echo To start in development mode:
echo   npm run dev
echo.
echo Admin panel will be available at: http://localhost:3000/admin
echo API endpoint: http://localhost:3000/api/version
echo.
pause
