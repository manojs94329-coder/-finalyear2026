@echo off
setlocal
echo ========================================================
echo   Push Ambulance Booking System to GitHub
echo ========================================================
echo.

set /p REPO_URL="Enter your GitHub Repository URL (e.g., https://github.com/username/repo.git): "

if "%REPO_URL%"=="" (
    echo [ERROR] No URL provided. Exiting.
    pause
    exit /b 1
)

echo.
echo [1/3] Setting remote origin to %REPO_URL%...
git remote remove origin >nul 2>&1
git remote add origin %REPO_URL%

echo [2/3] Setting default branch to main...
git branch -M main

echo [3/3] Pushing to GitHub...
git push -u origin main

if %ERRORLEVEL% equ 0 (
    echo.
    echo ========================================================
    echo   [SUCCESS] Successfully pushed project to GitHub!
    echo ========================================================
) else (
    echo.
    echo [NOTE] If git prompted for login/token, make sure to use your GitHub Personal Access Token (PAT).
)

echo.
pause
