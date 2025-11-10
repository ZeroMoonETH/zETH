#!/bin/bash

# Run Invariant Tests with Safe Configuration
# Uses audit profile (100K runs, depth 20) which is proven to work

echo "🔄 Running Invariant Tests (Safe Configuration)..."
echo "=========================================="
echo ""
echo "📊 Configuration: 100K runs, depth 20"
echo "💡 This configuration is proven to work and provides excellent coverage"
echo ""

TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Create test-reports directory if it doesn't exist
mkdir -p test-reports

echo "⏳ This will take approximately 4-5 minutes..."
echo ""

# Use audit profile instead of maximum (more memory-friendly)
FOUNDRY_PROFILE=audit forge test \
    --match-contract ZeroMoonInvariantTest \
    --json > "test-reports/invariant-audit-${TIMESTAMP}.json" 2>&1

EXIT_CODE=$?

if [ $EXIT_CODE -eq 0 ]; then
    echo ""
    echo "✅ Invariant tests completed successfully!"
    echo "📄 JSON log: test-reports/invariant-audit-${TIMESTAMP}.json"
    echo ""
    echo "📊 Results:"
    echo "   - 100,000 runs per invariant"
    echo "   - Depth: 20 calls per sequence"
    echo "   - Total: ~2,000,000 function calls"
else
    echo ""
    echo "❌ Invariant tests failed (exit code: $EXIT_CODE)"
    echo "📄 JSON log: test-reports/invariant-audit-${TIMESTAMP}.json"
fi

echo ""
echo "✨ Done!"

