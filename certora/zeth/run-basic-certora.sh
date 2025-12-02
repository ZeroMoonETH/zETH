#!/bin/bash

# ZeroMoon zETH - Basic Certora Verification
# Quick verification to test setup before running comprehensive version

set -e

# Get the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

echo "🚀 Starting ZeroMoon zETH Basic Certora Verification"
echo "================================================================"
echo ""
echo "This is a quick verification to test the setup."
echo "Run time: 10-30 minutes"
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

echo "📊 Running Basic Formal Verification..."
echo ""

# Run Certora with basic settings
certoraRun \
    src/ZeroMoon.sol \
    --verify ZeroMoon:zeth.spec \
    --msg "ZeroMoon zETH - Basic Verification" \
    2>&1 | tee "certora-results/basic-${TIMESTAMP}.log"

EXIT_CODE=$?

echo ""
echo "================================================================"
echo "📊 Verification Summary"
echo "================================================================"

if [ $EXIT_CODE -eq 0 ]; then
    echo "✅ Basic verification completed!"
    echo ""
    echo "📄 Results saved: certora-results/basic-${TIMESTAMP}.log"
    echo ""
    echo "Next step: Run comprehensive verification:"
    echo "  ./run-maximum-certora.sh"
else
    echo "❌ Verification found issues or timed out"
    echo "   Check the logs for details"
    echo ""
    echo "📄 Results saved: certora-results/basic-${TIMESTAMP}.log"
fi

echo ""
echo "================================================================"
echo ""

exit $EXIT_CODE

