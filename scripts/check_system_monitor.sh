#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
task_temp_dir=$(mktemp -d /tmp/aero-system-checks.XXXXXX)
trap 'rm -rf "$task_temp_dir"' EXIT
xcrun swiftc -parse-as-library Aero/Model/SystemMonitor.swift scripts/check_system_monitor.swift -o "$task_temp_dir/checks"
"$task_temp_dir/checks"
