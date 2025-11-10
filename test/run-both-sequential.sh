#!/bin/bash

# ZeroMoon Maximum Test Suite - Sequential Execution
# Runs fuzz and invariant tests one after another

echo "🚀 Starting ZeroMoon Maximum Test Suite (Sequential)..."
echo "=========================================="
echo ""

TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Create test-reports directory if it doesn't exist
mkdir -p test-reports

# Step 1: Fuzz Tests
echo "📊 Step 1/2: Running Unit Fuzz Tests (10M runs)..."
echo "This will take approximately 25-30 minutes..."
echo ""

FOUNDRY_PROFILE=maximum forge test \
    --match-contract ZeroMoonFuzzTest \
    --fuzz-runs 10000000 \
    --json > "test-reports/fuzz-maximum-${TIMESTAMP}.json" 2>&1

FUZZ_EXIT_CODE=$?

if [ $FUZZ_EXIT_CODE -eq 0 ]; then
    echo "✅ Fuzz tests completed successfully!"
    echo "📄 JSON log: test-reports/fuzz-maximum-${TIMESTAMP}.json"
else
    echo "❌ Fuzz tests failed (exit code: $FUZZ_EXIT_CODE)"
    echo "📄 JSON log: test-reports/fuzz-maximum-${TIMESTAMP}.json"
fi

echo ""
echo "=========================================="
echo ""

# Step 2: Invariant Tests
echo "🔄 Step 2/2: Running Invariant Tests (1M runs, depth 40)..."
echo "This will take approximately 20-25 minutes..."
echo ""

FOUNDRY_PROFILE=maximum forge test \
    --match-contract ZeroMoonInvariantTest \
    --json > "test-reports/invariant-maximum-${TIMESTAMP}.json" 2>&1

INVARIANT_EXIT_CODE=$?

if [ $INVARIANT_EXIT_CODE -eq 0 ]; then
    echo "✅ Invariant tests completed successfully!"
    echo "📄 JSON log: test-reports/invariant-maximum-${TIMESTAMP}.json"
else
    echo "❌ Invariant tests failed (exit code: $INVARIANT_EXIT_CODE)"
    echo "📄 JSON log: test-reports/invariant-maximum-${TIMESTAMP}.json"
fi

echo ""
echo "=========================================="
echo "📊 Final Summary"
echo "=========================================="
echo "Fuzz Tests:     $([ $FUZZ_EXIT_CODE -eq 0 ] && echo '✅ PASSED' || echo '❌ FAILED')"
echo "Invariant Tests: $([ $INVARIANT_EXIT_CODE -eq 0 ] && echo '✅ PASSED' || echo '❌ FAILED')"
echo ""
echo "📁 JSON Reports saved in test-reports/:"
echo "   - test-reports/fuzz-maximum-${TIMESTAMP}.json"
echo "   - test-reports/invariant-maximum-${TIMESTAMP}.json"
echo ""
echo "✨ All tests completed!"

