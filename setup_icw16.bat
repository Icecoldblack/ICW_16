@echo off
rem One-time setup for ICW_16. Finite script: creates the Android shell, installs
rem dependencies, links the Firebase project, deploys firestore.rules. Log: setup.log
cd /d "%~dp0"
call :main > setup.log 2>&1
type setup.log
echo.
echo ===== finished, see setup.log =====
pause
exit /b

:main
where flutter >nul 2>nul
if errorlevel 1 (
  if exist "%USERPROFILE%\Flutter SDK\flutter\bin" set "PATH=%USERPROFILE%\Flutter SDK\flutter\bin;%PATH%"
  if exist "%USERPROFILE%\Flutter SDK\bin" set "PATH=%USERPROFILE%\Flutter SDK\bin;%PATH%"
)
set "PATH=%LOCALAPPDATA%\Pub\Cache\bin;%PATH%"
echo === flutter create ===
call flutter create --org com.uyiosa --project-name icw16b --platforms android .
echo === dependencies ===
call flutter pub add http firebase_core firebase_auth cloud_firestore
call flutter pub get
echo === flutterfire ===
where flutterfire >nul 2>nul
if errorlevel 1 call dart pub global activate flutterfire_cli
call flutterfire configure --project=ica16-class-b-science-signal --platforms=android --android-package-name=com.uyiosa.icw16b --yes
echo === deploy rules ===
call firebase deploy --only firestore:rules --project ica16-class-b-science-signal
echo === emulators ===
call flutter emulators
exit /b 0
