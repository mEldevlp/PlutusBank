@echo off
setlocal EnableDelayedExpansion

rem %1 — полный путь до Server.exe, прокидывается из tasks.vs.json
set "SERVER_EXE=%~1"
set "PORT=9500"

if "%SERVER_EXE%"=="" (
    echo [pb-launcher] usage: start_server.bat ^<path-to-Server.exe^>
    exit /b 1
)

netstat -ano | findstr ":%PORT% " | findstr "LISTENING" >nul
if %errorlevel% == 0 (
    echo [pb-launcher] server already listening on %PORT%
    exit /b 0
)

echo [pb-launcher] starting "%SERVER_EXE%"
start "PlutusBank Server" /D "%~dp1" "%SERVER_EXE%"

for /l %%i in (1,1,30) do (
    timeout /t 1 /nobreak >nul
    netstat -ano | findstr ":%PORT% " | findstr "LISTENING" >nul
    if !errorlevel! == 0 (
        echo [pb-launcher] server ready on %PORT%
        exit /b 0
    )
)
echo [pb-launcher] WARNING: server did not become ready in 30s
exit /b 0