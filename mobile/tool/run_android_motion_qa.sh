#!/usr/bin/env bash
set -euo pipefail

scenario="${1:?usage: run_android_motion_qa.sh <home|calendar-drag|calendar-settled|startup>}"
cd mobile

if [[ "$scenario" == "startup" ]]; then
  cp build/app/outputs/flutter-apk/app-release.apk build/memory-hub-release.apk
  cp build/app/outputs/flutter-apk/app-baseline.apk build/memory-hub-baseline.apk

  adb install build/memory-hub-baseline.apk
  adb install -r build/memory-hub-release.apk
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
  exit 0
fi

case "$scenario" in
  home)
    marker='ANDROID_QA home-ready-for-screenshot'
    screenshot='build/android-motion-home-card-tilt.png'
    ;;
  calendar-drag)
    marker='ANDROID_QA calendar-native-drag-ready'
    screenshot='build/android-motion-calendar-month-drag.png'
    ;;
  calendar-settled)
    marker='ANDROID_QA calendar-native-settle-ready'
    screenshot='build/android-motion-calendar-month-settled.png'
    ;;
  *)
    echo "Unknown Android QA scenario: $scenario" >&2
    exit 2
    ;;
esac

# A native screenshot can invalidate SwiftShader buffers on hosted runners.
# Each workflow step therefore runs exactly one scenario on a fresh emulator.
adb uninstall com.glandy.memoryhub >/dev/null 2>&1 || true
adb logcat -c
flutter drive \
  --driver=test_driver/formal_android_motion_driver.dart \
  --target=integration_test/formal_android_motion_test.dart \
  --dart-define="MEMORY_HUB_QA_SCENARIO=$scenario" \
  -d emulator-5554 \
  --host-vmservice-port=8888 \
  --no-pub &
drive_pid=$!

for ((attempt = 0; attempt < 180; attempt++)); do
  if adb shell pm path com.glandy.memoryhub 2>/dev/null | grep -q '^package:'; then
    break
  fi
  if ! kill -0 "$drive_pid" 2>/dev/null; then
    wait "$drive_pid"
    echo 'Android QA driver exited before installing the debug app' >&2
    exit 1
  fi
  sleep 1
done
adb shell pm path com.glandy.memoryhub 2>/dev/null | grep -q '^package:'

# Let Flutter finish VM Service forwarding before polling its log marker.
sleep 10
for ((attempt = 0; attempt < 180; attempt++)); do
  adb logcat -d -v brief > build/android-qa-logcat-current.txt 2>/dev/null || true
  if grep -Fq "$marker" build/android-qa-logcat-current.txt; then
    if [[ "$scenario" == "calendar-drag" ]]; then
      adb shell input swipe 900 900 180 900 3000 &
      input_pid=$!
      sleep 2
      adb exec-out screencap -p > "$screenshot"
      wait "$input_pid"
    elif [[ "$scenario" == "calendar-settled" ]]; then
      adb shell input swipe 900 900 180 900 600
      sleep 1
      adb exec-out screencap -p > "$screenshot"
    else
      adb exec-out screencap -p > "$screenshot"
    fi
    break
  fi
  if ! kill -0 "$drive_pid" 2>/dev/null; then
    wait "$drive_pid"
    echo "Android QA driver exited before marker: $marker" >&2
    exit 1
  fi
  sleep 1
done

test -s "$screenshot"
wait "$drive_pid"
