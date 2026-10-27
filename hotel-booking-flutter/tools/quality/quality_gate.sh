#!/usr/bin/env bash
set -euo pipefail

# Minh Thanh Villa — Quality Gate & Release Readiness Runner

if [ -f "pubspec.yaml" ]; then
  PROJECT_DIR="."
elif [ -f "hotel-booking-flutter/pubspec.yaml" ]; then
  PROJECT_DIR="hotel-booking-flutter"
else
  echo "ERROR: Cannot locate hotel-booking-flutter/pubspec.yaml" >&2
  exit 1
fi

cd "$PROJECT_DIR"

echo "=== [1/4] Running Secret, Zero-Mock & FLUTTER_RULES Audit ==="
dart run tools/quality/secret_and_rule_audit.dart

echo "=== [2/4] Checking Dart Formatting ==="
dart format --output=none --set-exit-if-changed test/integration integration_test tools/quality

echo "=== [3/4] Running Static Analysis ==="
flutter analyze --no-fatal-infos test/integration integration_test tools/quality

echo "=== [4/4] Running Automated E2E & Visual Checklist Suites ==="
flutter test test/integration/e2e_all_flows_test.dart test/integration/visual_ui_checklist_test.dart

echo "=== QUALITY GATE PASSED ==="
