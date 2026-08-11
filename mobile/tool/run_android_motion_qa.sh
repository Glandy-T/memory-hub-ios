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
    pkill -KILL -f '^/usr/local/lib/android/sdk/emulator/emulator .* -avd test'
  ) >/dev/null 2>&1 &
  # Validate the delivered file itself instead of ADB's cleanup code.
  timeout --signal=KILL 12s adb exec-out screencap -p > "$target" || true
  python -c 'import pathlib,sys; d=pathlib.Path(sys.argv[1]).read_bytes(); assert len(d)>100000 and d[:8]==b"\x89PNG\r\n\x1a\n" and d[-12:-8]==b"\0\0\0\0" and d[-8:-4]==b"IEND", "incomplete Android PNG"' "$target"
}

start_android_recording() {
  android_recording_guest="/sdcard/memory-hub-${scenario}.mp4"
  android_recording_host="build/android-motion-${scenario}.mp4"
  adb shell rm -f "$android_recording_guest"
  adb shell screenrecord --bit-rate 8000000 --time-limit 6 "$android_recording_guest" >/dev/null 2>&1 &
  android_recording_pid=$!
}

finish_android_recording_frame() {
  local target="$1"
  local frame_second="$2"
  wait "$android_recording_pid"
  adb pull "$android_recording_guest" "$android_recording_host" >/dev/null
  ffmpeg -loglevel error -y -ss "$frame_second" -i "$android_recording_host" -frames:v 1 "$target"
  python -c 'import pathlib,sys; d=pathlib.Path(sys.argv[1]).read_bytes(); assert len(d)>100000 and d[:8]==b"\x89PNG\r\n\x1a\n" and d[-12:-8]==b"\0\0\0\0" and d[-8:-4]==b"IEND", "incomplete Android PNG"' "$target"
  rm -f "$android_recording_host"
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
setsid flutter drive \
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
      # Record before injecting the real pointer sequence. Extracting the
      # half-drag frame afterwards avoids interrupting Surface/SwiftShader
      # with screencap while Android still owns the pointer.
      start_android_recording
      sleep 1
      adb shell input swipe 900 900 180 900 3000
      finish_android_recording_frame "$screenshot" 3.0
    elif [[ "$scenario" == "calendar-settled" ]]; then
      start_android_recording
      sleep 1
      adb shell input swipe 900 900 180 900 600
      # Let the app assert the settled month before selecting the recorded
      # stable frame; the test keeps that centered state alive for capture.
      for ((settle_attempt = 0; settle_attempt < 30; settle_attempt++)); do
        adb logcat -d -v brief > build/android-qa-logcat-current.txt 2>/dev/null || true
        if grep -Fq 'ANDROID_QA calendar-native-settle-asserted' build/android-qa-logcat-current.txt; then
          break
        fi
        if ! kill -0 "$drive_pid" 2>/dev/null; then
          wait "$drive_pid"
          echo 'Android QA driver exited before the calendar settled assertion' >&2
          exit 1
        fi
        sleep 1
      done
      grep -Fq 'ANDROID_QA calendar-native-settle-asserted' build/android-qa-logcat-current.txt
      finish_android_recording_frame "$screenshot" 5.0
    else
      capture_android_frame "$screenshot"
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

# Native screencap can invalidate the hosted emulator's SwiftShader buffer.
# The scenario marker is emitted only after its in-app assertions, and the
# settled scenario additionally waits for its post-gesture assertion above.
# Once the PNG is safely on the host, do not let Flutter's best-effort ADB
# uninstall keep the workflow waiting on an emulator that screencap took
# offline; android-emulator-runner owns final emulator cleanup.
# The drive command owns its own session so this also stops any Flutter/ADB
# cleanup children without touching the workflow shell or emulator runner.
kill -KILL -- "-$drive_pid" 2>/dev/null || true
wait "$drive_pid" 2>/dev/null || true
