@echo off
rem Builds the release APK and copies it to ICA16_B_UyiosaNehikhuere.apk. Log: build.log
cd /d "%~dp0"
where flutter >nul 2>nul
if errorlevel 1 (
  if exist "%USERPROFILE%\Flutter SDK\flutter\bin" set "PATH=%USERPROFILE%\Flutter SDK\flutter\bin;%PATH%"
  if exist "%USERPROFILE%\Flutter SDK\bin" set "PATH=%USERPROFILE%\Flutter SDK\bin;%PATH%"
)
call :main > build.log 2>&1
type build.log
pause
exit /b
:main
call flutter test
call flutter analyze
call flutter build apk --release
copy /y "build\app\outputs\flutter-apk\app-release.apk" "ICA16_B_UyiosaNehikhuere.apk"
git rev-parse --short HEAD
exit /b 0
