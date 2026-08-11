#!/usr/bin/env bash
set -euo pipefail

cd mobile
cp build/app/outputs/flutter-apk/app-release.apk build/memory-hub-release.apk
cp build/app/outputs/flutter-apk/app-baseline.apk build/memory-hub-baseline.apk

adb install build/memory-hub-baseline.apk
adb install -r build/memory-hub-release.apk

flutter pub add 'dev:integration_test@{sdk: flutter}'
mkdir -p integration_test test_driver
cp tool/formal_android_motion_test.dart.template integration_test/formal_android_motion_test.dart
cp tool/formal_android_motion_driver.dart.template test_driver/formal_android_motion_driver.dart
flutter drive \
  --driver=test_driver/formal_android_motion_driver.dart \
  --target=integration_test/formal_android_motion_test.dart \
  -d emulator-5554 \
  --no-pub

adb uninstall com.glandy.memoryhub >/dev/null 2>&1 || true
adb install build/memory-hub-release.apk
adb logcat -c
adb shell am force-stop com.glandy.memoryhub
adb shell am force-stop com.android.launcher3 || true
adb shell am start -W -n com.glandy.memoryhub/.MainActivity
sleep 10
adb shell uiautomator dump /sdcard/memory-hub-window.xml >/dev/null
adb pull /sdcard/memory-hub-window.xml build/android-window.xml >/dev/null
adb logcat -d > build/android-startup-logcat.txt
adb exec-out screencap -p > build/android-startup.png
adb shell dumpsys activity activities > build/android-activity-state.txt
adb shell pidof com.glandy.memoryhub | grep -q '[0-9]'
grep -Eq '(mResumedActivity|topResumedActivity|ResumedActivity).*com\.glandy\.memoryhub' build/android-activity-state.txt
! grep -A 2 'FATAL EXCEPTION' build/android-startup-logcat.txt | grep -q 'Process: com.glandy.memoryhub'
! grep -Eqi "isn't responding|is not responding|Quickstep" build/android-window.xml

cp build/memory-hub-release.apk build/app/outputs/flutter-apk/app-release.apk
