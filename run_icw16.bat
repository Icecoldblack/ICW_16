@echo off
rem Starts the Pixel 9 Pro XL emulator and runs the app in debug (dev tools on). Log: run.log
cd /d "%~dp0"
where flutter >nul 2>nul
if errorlevel 1 (
  if exist "%USERPROFILE%\Flutter SDK\flutter\bin" set "PATH=%USERPROFILE%\Flutter SDK\flutter\bin;%PATH%"
  if exist "%USERPROFILE%\Flutter SDK\bin" set "PATH=%USERPROFILE%\Flutter SDK\bin;%PATH%"
)
if exist "%LOCALAPPDATA%\Android\Sdk\platform-tools" set "PATH=%LOCALAPPDATA%\Android\Sdk\platform-tools;%PATH%"
call flutter pub get
call flutter emulators --launch Pixel_9_Pro_XL
echo Waiting for the emulator to boot...
adb wait-for-device
timeout /t 40 /nobreak
call flutter devices
call flutter run -d emulator
pause
