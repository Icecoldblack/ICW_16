@echo off
rem Commits in several steps under Uyiosa Nehikhuere only (no co-author lines) and pushes to Icecoldblack/ICW_16.
cd /d "%~dp0"
if not exist .git git init -b main
git config user.name "Uyiosa Nehikhuere"
git config user.email "unehikhuere@gmail.com"
git remote remove origin 2>nul
git remote add origin https://github.com/Icecoldblack/ICW_16.git

git add .gitignore pubspec.yaml pubspec.lock analysis_options.yaml android
git commit -m "Scaffold Flutter project and Android shell"
git add firebase.json .firebaserc firestore.rules lib/firebase_options.dart
git commit -m "Add Firebase config and owner-only Firestore rules"
git add lib/opentdb.dart lib/dev_faults.dart test
git commit -m "Add Open Trivia client with strict decoding and validation, plus tests"
git add lib/attempt_repository.dart lib/quiz_controller.dart
git commit -m "Add create-once transaction, server-only verification and quiz state machine"
git add lib/main.dart lib/ui
git commit -m "Add sign-in, quiz, results, retrieval and dev-only fault tools UI"
git add README.md evidence setup_icw16.bat run_icw16.bat build_apk.bat push_to_github.bat
git commit -m "Add README, evidence and helper scripts"
git add -A
git commit -m "Final polish" 2>nul
git log --format="%%h %%an <%%ae> %%s"
git push -u origin main
pause
