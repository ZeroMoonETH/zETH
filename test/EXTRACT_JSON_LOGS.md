# Extracting JSON Logs from Test Runs

This guide explains how to extract JSON logs from your fuzz and invariant test runs for audit reports.

## Quick Commands

### Option 1: Run Tests with JSON Output (Recommended)

#### For Fuzz Tests:
```bash
FOUNDRY_PROFILE=maximum forge test \
    --match-contract ZeroMoonFuzzTest \
    --fuzz-runs 10000000 \
    --json > fuzz-maximum-report.json 2>&1
```

#### For Invariant Tests:
```bash
FOUNDRY_PROFILE=maximum forge test \
    --match-contract ZeroMoonInvariantTest \
    --json > invariant-maximum-report.json 2>&1
```

### Option 2: Use the Automated Script

#### Linux/Mac:
```bash
chmod +x test/run-maximum-tests.sh
./test/run-maximum-tests.sh
```

#### Windows (PowerShell):
```powershell
.\test\run-maximum-tests.ps1
```

## What the JSON Contains

The JSON output includes:

### For Fuzz Tests:
- Test results for each test function
- Number of runs per test
- Gas usage statistics (mean, median)
- Pass/fail status
- Counterexamples (if any failures)
- Execution time

### For Invariant Tests:
- Invariant results
- Number of runs per invariant
- Total calls made
- Revert counts
- Call statistics per contract/function
- Pass/fail status
- Execution time

## JSON Structure Example

```json
{
  "success": true,
  "testResults": [
    {
      "contract": "ZeroMoonFuzzTest",
      "test": "testFuzz_Buy",
      "status": "success",
      "runs": 10000000,
      "meanGas": 154024,
      "medianGas": 154128
    }
  ],
  "invariantResults": [
    {
      "contract": "ZeroMoonInvariantTest",
      "invariant": "invariant_backingNeverDecreases",
      "status": "success",
      "runs": 1000000,
      "calls": 20000000,
      "reverts": 11094460
    }
  ]
}
```

## If You've Already Run the Tests

If you've already run the tests without `--json`, you can:

1. **Re-run with JSON output** (recommended):
   ```bash
   # Just run with --json flag to capture output
   FOUNDRY_PROFILE=maximum forge test --match-contract ZeroMoonFuzzTest --fuzz-runs 10000000 --json > fuzz-report.json
   ```

2. **Check Foundry cache** (if available):
   - Foundry may cache some results in `.forge/` directory
   - But JSON output is only generated when using `--json` flag

## For Your Audit Report

Your colleague mentioned:
- **"40M state transitions, zero violations"** - This comes from:
  - 1M invariant runs × 40 depth = 40M maximum possible calls
  - But actual calls will be less due to reverts
  - Check the JSON for exact `calls` count

### Extracting Key Metrics from JSON

You can use `jq` (JSON processor) to extract metrics:

```bash
# Extract total calls from invariant tests
jq '.invariantResults[].calls' invariant-maximum-report.json

# Extract total runs
jq '.invariantResults[].runs' invariant-maximum-report.json

# Check for any failures
jq '.invariantResults[] | select(.status != "success")' invariant-maximum-report.json
```

## File Locations

After running, your JSON files will be in:
- `fuzz-maximum-report.json` (or timestamped version)
- `invariant-maximum-report.json` (or timestamped version)
- Or in `test-reports/` directory if using the script

## Next Steps

1. ✅ Run tests with `--json` flag
2. ✅ Save JSON files
3. ✅ Screenshot final tables (from terminal output)
4. ✅ Extract metrics for audit report
5. ✅ Publish `ZeroMoonInvariant.t.sol` (already in your repo)

## Notes

- JSON output is large (can be 10-50MB for 10M runs)
- Make sure you have enough disk space
- JSON includes all test details, perfect for audit reports
- You can compress JSON files if needed: `gzip *.json`

