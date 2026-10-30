#!/usr/bin/env pwsh
<#
.SYNOPSIS
  Minh Thanh Villa — Quality Gate & Release Readiness Runner
.DESCRIPTION
  Runs:
  1. Secret, Zero-Mock & FLUTTER_RULES Audit
  2. dart format verification
  3. flutter analyze verification
  4. Unit, Widget & Integration E2E tests (320/360/390/430dp + text scale 1.0/1.3/1.6)
#>
param(
  [switch]$StrictDesign = $false,
  [switch]$BuildApk = $false
)

$ErrorActionPreference = "Stop"

$ProjectDir = if (Test-Path "pubspec.yaml") {
  Get-Location
} elseif (Test-Path "hotel-booking-flutter/pubspec.yaml") {
  Join-Path (Get-Location) "hotel-booking-flutter"
} else {
  throw "Cannot locate hotel-booking-flutter/pubspec.yaml"
}

Push-Location $ProjectDir
try {
  Write-Host "=== [1/5] Running Secret & FLUTTER_RULES Audit ===" -ForegroundColor Cyan
  if ($StrictDesign) {
    dart run tools/quality/secret_and_rule_audit.dart --strict-design
  } else {
    dart run tools/quality/secret_and_rule_audit.dart
  }
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

  Write-Host "=== [2/5] Checking Dart Formatting ===" -ForegroundColor Cyan
  dart format --output=none --set-exit-if-changed test/integration integration_test tools/quality
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

  Write-Host "=== [3/5] Running Flutter Analyze on QA & Integration Suites ===" -ForegroundColor Cyan
  flutter analyze --no-fatal-infos test/integration integration_test tools/quality
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

  Write-Host "=== [4/5] Running Automated E2E & Visual Checklist Tests ===" -ForegroundColor Cyan
  flutter test test/integration/e2e_all_flows_test.dart test/integration/visual_ui_checklist_test.dart
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

  if ($BuildApk) {
    Write-Host "=== [5/5] Building Debug/Staging Android APK ===" -ForegroundColor Cyan
    flutter build apk --debug --flavor staging --dart-define=APP_ENV=staging --dart-define=API_BASE_URL=https://staging-api.minhthanhvilla.com
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
  }
  Write-Host "=== QUALITY GATE COMPLETED SUCCESSFULLY ===" -ForegroundColor Green
} finally {
  Pop-Location
}
