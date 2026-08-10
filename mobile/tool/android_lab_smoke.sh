#!/usr/bin/env bash
set -euo pipefail

dump_ui() {
  for attempt in 1 2 3; do
    if adb shell uiautomator dump /sdcard/memory-hub-window.xml >/dev/null; then
      break
    fi
    if [[ "$attempt" == 3 ]]; then
      return 1
    fi
    sleep 1
  done
  adb pull /sdcard/memory-hub-window.xml /tmp/memory-hub-window.xml >/dev/null
}

node_center() {
  local label="$1"
  dump_ui
  python3 - "$label" <<'PY'
import re
import sys
import xml.etree.ElementTree as ET

needle = sys.argv[1]
root = ET.parse('/tmp/memory-hub-window.xml').getroot()
matches = []
for node in root.iter('node'):
    value = ' '.join((node.attrib.get('text', ''), node.attrib.get('content-desc', '')))
    if needle not in value:
        continue
    match = re.fullmatch(r'\[(\d+),(\d+)\]\[(\d+),(\d+)\]', node.attrib.get('bounds', ''))
    if match:
        left, top, right, bottom = map(int, match.groups())
        area = max(1, right - left) * max(1, bottom - top)
        matches.append((area, left, top, right, bottom))
if not matches:
    raise SystemExit(f'找不到界面元素：{needle}')
_, left, top, right, bottom = min(matches)
print(f'{(left + right) // 2} {(top + bottom) // 2}')
PY
}

tap_text() {
  local point
  point="$(node_center "$1")"
  echo "tap: $1 => $point" >&2
  adb shell input tap $point
  sleep 1
}

assert_text() {
  node_center "$1" >/dev/null
}

screenshot() {
  adb exec-out screencap -p > "mobile/build/android-lab-$1.png"
}

assert_text '先记下来'
screenshot onboarding
tap_text '开始'
assert_text '选择常用功能'
tap_text '继续'
assert_text '保存方式'
tap_text '进入首页'
assert_text '今日事项'
screenshot home

tap_text '快速记录'
assert_text '存入待收录'
tap_text '想到什么？'
adb shell input text 'call%sthe%sclinic%stomorrow'
tap_text '存入待收录'
assert_text '已加入待收录'
sleep 3

tap_text '我的'
adb shell input swipe 540 1700 540 650 450
sleep 1
tap_text '实验版待收录'
assert_text 'call the clinic tomorrow'
screenshot pending
tap_text 'call the clinic tomorrow'
assert_text '确认安排'
tap_text '确认收录'
assert_text '还没有待收录内容'

adb shell input keyevent 4
sleep 1
tap_text '首页'
tap_text 'call the clinic tomorrow'
assert_text '下一步'
tap_text '拆成几步'
tap_text '刚刚好'
assert_text '整理步骤'
assert_text '当前下一步'
screenshot steps
tap_text '保存'
tap_text '开始专注'
assert_text '只做这一件'
tap_text '暂停'
assert_text '离开前做到哪里？'
tap_text '进度备注'
adb shell input text 'found%sthe%sphone%snumber'
tap_text '保存并暂停'
assert_text '专注已暂停'
assert_text 'found the phone number'
screenshot focus-paused

tap_text '退出'
adb shell input keyevent 4
sleep 1
tap_text '日历'
tap_text '时间线'
assert_text '今天还留有约'
assert_text '常用流程'
screenshot timeline
