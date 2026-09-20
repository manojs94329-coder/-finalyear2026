@echo off
title Ambulance Booking Flutter App (Chrome)
echo Starting Flutter App on Chrome...
cd /d "%~dp0mobile\ambulance_booking_app"
flutter run -d chrome --web-hostname 127.0.0.1 --web-port 8088
pause
