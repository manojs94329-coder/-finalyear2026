@echo off
title Ambulance Booking API
echo Starting ASP.NET Core Web API on http://localhost:5000 ...
cd /d "%~dp0backend\AmbulanceBooking.Api"
dotnet run --launch-profile http
pause
