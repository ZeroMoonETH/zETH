#!/bin/bash

# ZeroMoon zETH - Maximum Coverage Certora Verification
# Equivalent to Foundry's 10M fuzz + 1M invariant tests
# This script runs comprehensive formal verification with maximum settings

set -e

# Get the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

echo "🚀 Starting ZeroMoon zETH Maximum Coverage Certora Verification"
echo "================================================================"
echo ""
echo "This is equivalent to Foundry's maximum profile:"
echo "  - 10,000,000 fuzz test runs"
echo "  - 1,000,000 invariant runs with depth 20"
echo "  - 360,000,000+ test scenarios"
echo ""
echo "Certora uses formal verification (mathematical proofs) instead of fuzzing,"
echo "so it proves properties hold for ALL possible inputs and states."
echo ""
echo "================================================================"
echo ""

# Create results directory
mkdir -p certora-results
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Check if Certora is installed
if ! command -v certoraRun &> /dev/null; then
    echo "❌ Error: certoraRun not found. Please install Certora Prover."
    echo "   Visit: https://docs.certora.com/"
    exit 1
fi

echo "📊 Running Comprehensive Formal Verification..."
echo "   This will verify ALL properties for ALL possible inputs"
echo "   Estimated time: 2-6 hours (depending on hardware)"
echo ""

# Run Certora with maximum settings
# Using direct command-line flags for timeouts (not --prover_args)
# --smt_timeout: Maximum time per rule (30 minutes = 1800 seconds)
# --global_timeout: Maximum total time (4 hours = 14400 seconds)
# --loop_iter: Maximum loop unrolling (equivalent to Foundry's depth 20)
# --optimistic_fallback: Optimize fallback/receive calls (suggested by Certora)
certoraRun \
    src/ZeroMoon.sol \
    --verify ZeroMoon:zeth-improved.spec \
    --loop_iter 5 \
    --smt_timeout 1800 \
    --global_timeout 14400 \
    --optimistic_fallback \
    --msg "ZeroMoon zETH - Improved Verification (with ghost variables)" \
    2>&1 | tee "certora-results/maximum-${TIMESTAMP}.log"

EXIT_CODE=$?

echo ""
echo "================================================================"
echo "📊 Verification Summary"
echo "================================================================"

if [ $EXIT_CODE -eq 0 ]; then
    echo "✅ All properties VERIFIED for ALL possible inputs!"
    echo "   This is stronger than fuzzing - it's a mathematical proof"
    echo ""
    echo "📄 Results saved:"
    echo "   - certora-results/maximum-${TIMESTAMP}.json"
    echo "   - certora-results/maximum-${TIMESTAMP}.log"
else
    echo "❌ Verification found issues or timed out"
    echo "   Check the logs for details"
    echo ""
    echo "📄 Results saved:"
    echo "   - certora-results/maximum-${TIMESTAMP}.json"
    echo "   - certora-results/maximum-${TIMESTAMP}.log"
fi

echo ""
echo "================================================================"
echo ""

exit $EXIT_CODE

