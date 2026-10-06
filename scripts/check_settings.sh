#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
task_temp_dir=$(mktemp -d /tmp/aero-settings-checks.XXXXXX)
trap 'rm -rf "$task_temp_dir"' EXIT
xcrun swiftc -parse-as-library Aero/Model/Settings.swift scripts/check_settings.swift -o "$task_temp_dir/checks"
"$task_temp_dir/checks"
