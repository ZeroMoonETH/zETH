#!/bin/bash

# ZeroMoon Maximum Test Suite - Parallel Execution
# Runs fuzz and invariant tests simultaneously (faster on multi-core systems)

echo "🚀 Starting ZeroMoon Maximum Test Suite (Parallel)..."
echo "=========================================="
echo ""
echo "💡 Running both test suites in parallel to save time"
echo "   (Uses multiple CPU cores simultaneously)"
echo ""

TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Create test-reports directory if it doesn't exist
mkdir -p test-reports

# Run both tests in background
echo "📊 Starting Fuzz Tests (10M runs) in background..."
FOUNDRY_PROFILE=maximum forge test \
    --match-contract ZeroMoonFuzzTest \
    --fuzz-runs 10000000 \
    --json > "test-reports/fuzz-maximum-${TIMESTAMP}.json" 2>&1 &
FUZZ_PID=$!

echo "🔄 Starting Invariant Tests (1M runs, depth 40) in background..."
FOUNDRY_PROFILE=maximum forge test \
    --match-contract ZeroMoonInvariantTest \
    --json > "test-reports/invariant-maximum-${TIMESTAMP}.json" 2>&1 &
INVARIANT_PID=$!

echo ""
echo "⏳ Both tests running in parallel..."
echo "   Fuzz PID: $FUZZ_PID"
echo "   Invariant PID: $INVARIANT_PID"
echo ""
echo "💡 Estimated time: ~30-35 minutes (running in parallel)"
echo "   (vs ~50-55 minutes if run sequentially)"
echo ""

# Wait for both to complete
wait $FUZZ_PID
FUZZ_EXIT_CODE=$?

wait $INVARIANT_PID
INVARIANT_EXIT_CODE=$?

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

