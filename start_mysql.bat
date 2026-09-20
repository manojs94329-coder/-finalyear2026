@echo off
title MySQL Database Server
echo Starting MySQL Database on port 3306...
"D:\mysql-8.0.46-winx64\mysql-8.0.46-winx64\bin\mysqld.exe" --defaults-file="D:\mysql-8.0.46-winx64\mysql-8.0.46-winx64\my.ini" --console
pause
