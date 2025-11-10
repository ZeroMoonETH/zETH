#!/bin/bash

# Run only Invariant Tests (if fuzz tests already completed)
# Configuration: 1M runs, depth 20 (proven to work)

echo "🔄 Running Invariant Tests Only (1M runs, depth 20)..."
echo "=========================================="
echo ""

TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Create test-reports directory if it doesn't exist
mkdir -p test-reports

echo "⏳ This will take approximately 20-25 minutes..."
echo ""

FOUNDRY_PROFILE=maximum forge test \
    --match-contract ZeroMoonInvariantTest \
    --json > "test-reports/invariant-maximum-${TIMESTAMP}.json" 2>&1

EXIT_CODE=$?

if [ $EXIT_CODE -eq 0 ]; then
    echo ""
    echo "✅ Invariant tests completed successfully!"
    echo "📄 JSON log: test-reports/invariant-maximum-${TIMESTAMP}.json"
    echo ""
    echo "📊 Configuration used:"
    echo "   - Runs: 1,000,000 per invariant"
    echo "   - Depth: 20 calls per sequence"
    echo "   - Total: ~20,000,000 function calls"
else
    echo ""
    echo "❌ Invariant tests failed (exit code: $EXIT_CODE)"
    echo "📄 JSON log: test-reports/invariant-maximum-${TIMESTAMP}.json"
    echo ""
    if [ $EXIT_CODE -eq 137 ]; then
        echo "⚠️  Process was killed (likely out of memory)"
        echo "   Try using the audit profile instead: ./test/run-invariant-safe.sh"
    fi
fi

echo ""
echo "✨ Done!"

