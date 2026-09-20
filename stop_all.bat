@echo off
title Stop Ambulance Booking System
echo Stopping running instances of the backend API and MySQL...

taskkill /F /IM AmbulanceBooking.Api.exe >nul 2>&1
taskkill /F /IM mysqld.exe >nul 2>&1

echo All components stopped.
pause
