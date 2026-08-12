#!/usr/bin/env bash
set -euo pipefail

scenario="${1:?usage: run_android_motion_qa.sh <home|calendar-drag|calendar-settled|startup>}"
cd mobile

capture_android_frame() {
  local target="$1"
  rm -f "$target"
  # SwiftShader may disconnect ADB after delivering the complete PNG, leaving
  # the client in an uninterruptible device wait. A detached watchdog kills
  # only this CI AVD so the kernel releases that wait even if `timeout` cannot.
  (
    sleep 20
    pkill -KILL -f ' -avd test( |$)'
  ) >/dev/null 2>&1 &
  local watchdog_pid=$!
  # Validate the delivered file itself instead of ADB's cleanup code.
  timeout --signal=KILL 12s adb exec-out screencap -p > "$target" || true
  # A completed capture must disarm and reap its watchdog. Otherwise the
  # delayed process can survive this emulator-runner action and kill the next
  # scenario's newly booted AVD in the same GitHub Actions job.
  kill "$watchdog_pid" >/dev/null 2>&1 || true
  wait "$watchdog_pid" 2>/dev/null || true
  python -c 'import pathlib,sys; d=pathlib.Path(sys.argv[1]).read_bytes(); assert len(d)>100000 and d[:8]==b"\x89PNG\r\n\x1a\n" and d[-12:-8]==b"\0\0\0\0" and d[-8:-4]==b"IEND", "incomplete Android PNG"' "$target"
}

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
  capture_android_frame build/android-startup.png
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
    screenshot='build/android-motion-home-card-tilt.png'
    ;;
  calendar-drag)
    screenshot='build/android-motion-calendar-month-drag.png'
    ;;
  calendar-settled)
    screenshot='build/android-motion-calendar-month-settled.png'
    ;;
  *)
    echo "Unknown Android QA scenario: $scenario" >&2
    exit 2
    ;;
esac

rm -f "$screenshot"

# Each workflow step runs one real gesture scenario on a fresh emulator.
# Flutter captures its own rendered test frame and the extended integration
# driver writes the PNG directly to the host, avoiding SurfaceFlinger readback.
adb uninstall com.glandy.memoryhub >/dev/null 2>&1 || true
adb logcat -c
adb shell wm size 540x1200
adb shell wm density 280
flutter drive \
  --driver=test_driver/formal_android_motion_driver.dart \
  --target=integration_test/formal_android_motion_test.dart \
  --dart-define="MEMORY_HUB_QA_SCENARIO=$scenario" \
  -d emulator-5554 \
  --host-vmservice-port=8888 \
  --no-pub

test -s "$screenshot"
python -c 'import pathlib,sys; d=pathlib.Path(sys.argv[1]).read_bytes(); assert len(d)>100000 and d[:8]==b"\x89PNG\r\n\x1a\n" and d[-12:-8]==b"\0\0\0\0" and d[-8:-4]==b"IEND", "incomplete Android PNG"' "$screenshot"
