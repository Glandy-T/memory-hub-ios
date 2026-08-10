#!/usr/bin/env bash
set -euo pipefail

cd mobile
cp build/app/outputs/flutter-apk/app-release.apk build/memory-hub-lab-release.apk

flutter pub add 'dev:integration_test@{sdk: flutter}'
mkdir -p integration_test test_driver
cp tool/lab_android_flow_test.dart.template integration_test/lab_android_flow_test.dart
cp tool/lab_android_driver.dart.template test_driver/integration_test.dart
flutter drive \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/lab_android_flow_test.dart \
  -d emulator-5554 \
  --no-pub

cd ..
adb logcat -c
adb install -r mobile/build/memory-hub-lab-release.apk
adb shell am force-stop com.glandy.memoryhub.lab
adb shell monkey -p com.glandy.memoryhub.lab -c android.intent.category.LAUNCHER 1
sleep 10
adb logcat -d > mobile/build/android-lab-startup-logcat.txt
adb exec-out screencap -p > mobile/build/android-lab-startup.png
adb shell dumpsys activity activities > mobile/build/android-lab-activity-state.txt
adb shell dumpsys window > mobile/build/android-lab-window-state.txt
adb shell pidof com.glandy.memoryhub.lab | grep -q '[0-9]'
grep -Eq '(mResumedActivity|topResumedActivity|ResumedActivity).*com\.glandy\.memoryhub\.lab' mobile/build/android-lab-activity-state.txt
! grep -A 2 'FATAL EXCEPTION' mobile/build/android-lab-startup-logcat.txt | grep -q 'Process: com.glandy.memoryhub.lab'
