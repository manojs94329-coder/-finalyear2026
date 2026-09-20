@echo off
title Ambulance Booking Cloud Tunnel
echo ========================================================
echo Starting Cloudflare Tunnel for Ambulance Booking System...
echo ========================================================
echo Ensure Backend API is running on http://localhost:5000 first.
echo.
"D:\cloudflared.exe" tunnel --url http://localhost:5000
pause
