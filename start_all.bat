@echo off
title Ambulance Booking System Launcher
echo ========================================================
echo Starting Ambulance Booking System...
echo ========================================================

netstat -ano | findstr :3306 >nul
if %errorlevel% equ 0 (
    echo [1/3] MySQL Database is already running on port 3306.
) else (
    echo [1/3] Starting MySQL Database...
    start "MySQL Server (Port 3306)" cmd /k ""%~dp0start_mysql.bat""
    timeout /t 3 /nobreak >nul
)

netstat -ano | findstr :5000 >nul
if %errorlevel% equ 0 (
    echo [2/3] Backend API is already running on port 5000.
) else (
    echo [2/3] Starting Backend API...
    start "Ambulance Booking API (Port 5000)" cmd /k ""%~dp0start_backend.bat""
    timeout /t 5 /nobreak >nul
)

echo [3/3] Opening Ambulance Booking App in your browser...
start http://localhost:5000

echo ========================================================
echo App is ready!
echo - Web App: http://localhost:5000
echo - API Swagger: http://localhost:5000/swagger
echo ========================================================
pause
