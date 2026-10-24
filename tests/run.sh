#!/usr/bin/env bash
# Offline tests: BarWidget.qml parses, then runs headless (Qt's `qml` on the
# offscreen platform, no display variables) with stand-in Quickshell and
# Omarchy modules against a local fixture server. Nothing reaches the real
# arena API or a live shell. Needs Qt 6 (qml, qmlformat) and python3.
set -euo pipefail
cd "$(dirname "$0")/.."

QT_BIN="${QT_BIN:-/usr/lib/qt6/bin}"
QML="${QML:-$QT_BIN/qml}"
[[ -x "$QML" ]] || { echo "tests: Qt 6 qml runtime not found (set QML=)" >&2; exit 1; }

# 1. Syntax gate: qmlformat refuses a file that does not parse.
for f in BarWidget.qml tests/widget_test.qml; do
  "$QT_BIN/qmlformat" "$f" >/dev/null || { echo "FAIL: $f does not parse" >&2; exit 1; }
done
jq -e . manifest.json >/dev/null
echo "ok   QML parses, manifest is JSON"

work="$(mktemp -d)"
server=""
cleanup() { [[ -n "$server" ]] && kill "$server" 2>/dev/null; rm -rf "$work"; }
trap cleanup EXIT

# 2. The player kit's session file, as `node sley-arena.mjs login` writes it.
printf '{"session":"not-a-real-token","login":"ada","api":"http://127.0.0.1/"}\n' >"$work/session.json"

python3 -I tests/arena_server.py >"$work/port" &
server=$!
for _ in $(seq 50); do [[ -s "$work/port" ]] && break; sleep 0.1; done
port="$(cat "$work/port")"
[[ -n "$port" ]] || { echo "FAIL: fixture server did not start" >&2; exit 1; }

out="$(env -u WAYLAND_DISPLAY -u DISPLAY -u HYPRLAND_INSTANCE_SIGNATURE \
  QT_QPA_PLATFORM=offscreen QT_QPA_PLATFORMTHEME= QT_FORCE_STDERR_LOGGING=1 QML_XHR_ALLOW_FILE_READ=1 \
  timeout 60 "$QML" -I tests/stubs tests/widget_test.qml -- "--port=$port" "--home=$work" 2>&1)" && rc=0 || rc=$?
{ grep -E '^qml: (ok|FAIL|SleyArena)|FAIL:' <<<"$out" || true; } | sed 's/^qml: //'
if (( rc != 0 )); then
  grep -vE '^qml: (ok|FAIL|SleyArena)' <<<"$out" >&2 || true
  echo "FAIL: widget tests (exit $rc)" >&2
  exit 1
fi
echo "ok"
