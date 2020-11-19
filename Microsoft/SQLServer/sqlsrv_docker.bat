@echo off
echo This script will build a SQL Server 2019 docker image and start a container using it.
echo.
echo If you want to continue, press any key or Ctrl+C to exit
echo.
pause

powershell -executionpolicy bypass -File "docker_setup.ps1"