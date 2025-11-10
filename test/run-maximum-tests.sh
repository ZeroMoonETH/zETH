#!/bin/bash

# ZeroMoon Maximum Test Suite Runner
# Generates JSON logs for both fuzz and invariant tests

echo "🚀 Starting ZeroMoon Maximum Test Suite..."
echo "=========================================="
echo ""

# Create output directory
mkdir -p test-reports
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

echo "📊 Running Unit Fuzz Tests (10M runs)..."
echo "This will take approximately 25-30 minutes..."
echo ""

# Run fuzz tests with JSON output
FOUNDRY_PROFILE=maximum forge test \
    --match-contract ZeroMoonFuzzTest \
    --fuzz-runs 10000000 \
    --json > "test-reports/fuzz-maximum-${TIMESTAMP}.json" 2>&1

FUZZ_EXIT_CODE=$?

if [ $FUZZ_EXIT_CODE -eq 0 ]; then
    echo "✅ Fuzz tests completed successfully!"
    echo "📄 JSON log saved: test-reports/fuzz-maximum-${TIMESTAMP}.json"
else
    echo "❌ Fuzz tests failed with exit code: $FUZZ_EXIT_CODE"
    echo "📄 JSON log saved: test-reports/fuzz-maximum-${TIMESTAMP}.json"
fi

echo ""
echo "=========================================="
echo ""

echo "🔄 Running Invariant Tests (1M runs, depth 40)..."
echo "This will take approximately 20-25 minutes..."
echo ""

# Run invariant tests with JSON output
FOUNDRY_PROFILE=maximum forge test \
    --match-contract ZeroMoonInvariantTest \
    --json > "test-reports/invariant-maximum-${TIMESTAMP}.json" 2>&1

INVARIANT_EXIT_CODE=$?

if [ $INVARIANT_EXIT_CODE -eq 0 ]; then
    echo "✅ Invariant tests completed successfully!"
    echo "📄 JSON log saved: test-reports/invariant-maximum-${TIMESTAMP}.json"
else
    echo "❌ Invariant tests failed with exit code: $INVARIANT_EXIT_CODE"
    echo "📄 JSON log saved: test-reports/invariant-maximum-${TIMESTAMP}.json"
fi

echo ""
echo "=========================================="
echo "📊 Test Suite Summary"
echo "=========================================="
echo "Fuzz Tests:     $([ $FUZZ_EXIT_CODE -eq 0 ] && echo '✅ PASSED' || echo '❌ FAILED')"
echo "Invariant Tests: $([ $INVARIANT_EXIT_CODE -eq 0 ] && echo '✅ PASSED' || echo '❌ FAILED')"
echo ""
echo "📁 All JSON logs saved in: test-reports/"
echo "   - fuzz-maximum-${TIMESTAMP}.json"
echo "   - invariant-maximum-${TIMESTAMP}.json"
echo ""
echo "✨ Done!"

