@echo off
echo This script will build a SQL Server docker image and start a container using it.
echo.
echo ### IMPORTANT ###
echo To use this script, you should have Docker Desktop installed and running properly on this host.
echo Ensure that Docker service is up and running with command (docker version) before continuing.
echo.
set /p vResponse="Do you want to continue? (Y/N) "

IF /i %vResponse% EQU Y GOTO yes
IF /i %vResponse% EQU N GOTO end
IF /i %vResponse% NEQ Y IF /i %vResponse% NEQ N GOTO invalid

:yes
powershell -executionpolicy bypass -File "bin\docker_setup.ps1"
GOTO end

:invalid
echo.
echo Invalid Option.
GOTO end

:end
echo.
echo End of script.
pause