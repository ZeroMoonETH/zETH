# ZeroMoon Maximum Test Suite Runner (PowerShell)
# Generates JSON logs for both fuzz and invariant tests

Write-Host "🚀 Starting ZeroMoon Maximum Test Suite..." -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

# Create output directory
$outputDir = "test-reports"
if (-not (Test-Path $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir | Out-Null
}

$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"

Write-Host "📊 Running Unit Fuzz Tests (10M runs)..." -ForegroundColor Yellow
Write-Host "This will take approximately 25-30 minutes..." -ForegroundColor Yellow
Write-Host ""

# Run fuzz tests with JSON output
$env:FOUNDRY_PROFILE = "maximum"
$fuzzOutput = "test-reports\fuzz-maximum-$timestamp.json"

forge test `
    --match-contract ZeroMoonFuzzTest `
    --fuzz-runs 10000000 `
    --json *> $fuzzOutput

$fuzzExitCode = $LASTEXITCODE

if ($fuzzExitCode -eq 0) {
    Write-Host "✅ Fuzz tests completed successfully!" -ForegroundColor Green
    Write-Host "📄 JSON log saved: $fuzzOutput" -ForegroundColor Green
} else {
    Write-Host "❌ Fuzz tests failed with exit code: $fuzzExitCode" -ForegroundColor Red
    Write-Host "📄 JSON log saved: $fuzzOutput" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "🔄 Running Invariant Tests (1M runs, depth 40)..." -ForegroundColor Yellow
Write-Host "This will take approximately 20-25 minutes..." -ForegroundColor Yellow
Write-Host ""

# Run invariant tests with JSON output
$invariantOutput = "test-reports\invariant-maximum-$timestamp.json"

forge test `
    --match-contract ZeroMoonInvariantTest `
    --json *> $invariantOutput

$invariantExitCode = $LASTEXITCODE

if ($invariantExitCode -eq 0) {
    Write-Host "✅ Invariant tests completed successfully!" -ForegroundColor Green
    Write-Host "📄 JSON log saved: $invariantOutput" -ForegroundColor Green
} else {
    Write-Host "❌ Invariant tests failed with exit code: $invariantExitCode" -ForegroundColor Red
    Write-Host "📄 JSON log saved: $invariantOutput" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "📊 Test Suite Summary" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Fuzz Tests:      $(if ($fuzzExitCode -eq 0) { '✅ PASSED' } else { '❌ FAILED' })"
Write-Host "Invariant Tests: $(if ($invariantExitCode -eq 0) { '✅ PASSED' } else { '❌ FAILED' })"
Write-Host ""
Write-Host "📁 All JSON logs saved in: test-reports\" -ForegroundColor Cyan
Write-Host "   - fuzz-maximum-$timestamp.json"
Write-Host "   - invariant-maximum-$timestamp.json"
Write-Host ""
Write-Host "✨ Done!" -ForegroundColor Green

