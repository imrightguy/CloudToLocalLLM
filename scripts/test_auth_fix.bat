@echo off
echo ========================================
echo Testing SimpleTunnelClient Auth Fix
echo ========================================
echo.

echo 1. Building application...
flutter build windows --debug
if %ERRORLEVEL% neq 0 (
    echo ERROR: Build failed
    exit /b 1
)
echo ✓ Build successful

echo.
echo 2. Running application for 10 seconds to test startup...
echo   - Application should start without authentication exceptions
echo   - Look for "User not authenticated, waiting for authentication" in logs
echo   - Press Ctrl+C to stop early if needed
echo.

timeout /t 3 /nobreak > nul
start /b flutter run -d windows > app_output.log 2>&1
timeout /t 10 /nobreak > nul

echo.
echo 3. Checking logs for authentication behavior...
findstr /i "authentication" app_output.log > auth_logs.txt
findstr /i "tunnel" app_output.log >> auth_logs.txt
findstr /i "exception" app_output.log >> auth_logs.txt

if exist auth_logs.txt (
    echo ✓ Found authentication-related logs:
    type auth_logs.txt
) else (
    echo ! No authentication logs found
)

echo.
echo 4. Cleaning up...
taskkill /f /im zoidbot.exe > nul 2>&1
del auth_logs.txt > nul 2>&1

echo.
echo ========================================
echo Test completed. Check app_output.log for full details.
echo Expected behavior:
echo - No "TunnelException" or "AUTH_TOKEN_MISSING" errors
echo - "User not authenticated, waiting for authentication" message
echo - Application starts successfully
echo ========================================
