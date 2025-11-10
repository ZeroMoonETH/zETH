# ZeroMoon zETH - Enhanced Fuzz Testing Guide

This guide explains how to run the comprehensive fuzz testing suite for the ZeroMoon zETH contract.

## Test Suite Overview

The fuzz testing suite consists of three types of tests:

1. **Unit Fuzz Tests** (`ZeroMoonFuzz.t.sol`) - Tests individual functions with random inputs
2. **Stateful Fuzz Tests** (`ZeroMoonInvariant.t.sol`) - Tests protocol-level invariants across complex call sequences
3. **Differential Fuzz Tests** (`ZeroMoonDifferential.t.sol`) - Compares contract behavior vs reference model

## Running the Tests

### Unit Fuzz Tests (Standard)

```bash
# Run with default runs (256)
forge test --match-contract ZeroMoonFuzzTest

# Run with 100,000 fuzz runs
forge test --match-contract ZeroMoonFuzzTest --fuzz-runs 100000

# Run with 10,000,000 fuzz runs (comprehensive)
forge test --match-contract ZeroMoonFuzzTest --fuzz-runs 10000000
```

### Stateful Fuzz Tests (Invariant Campaigns)

```bash
# Run with default settings (from foundry.toml)
forge test --match-contract ZeroMoonInvariantTest

# Run with CI profile (10,000 runs, depth 15)
FOUNDRY_PROFILE=ci forge test --match-contract ZeroMoonInvariantTest

# Run with audit profile (100,000 runs, depth 20)
FOUNDRY_PROFILE=audit forge test --match-contract ZeroMoonInvariantTest
```

**Note:** Invariant runs and depth are configured in `foundry.toml`. Use `FOUNDRY_PROFILE` environment variable to select a profile.

**What is Invariant Testing?**
- Tests protocol-level properties that must hold across **any sequence** of calls
- Uses a handler contract to generate complex call sequences
- Validates invariants like "backing never decreases" across thousands of random transaction sequences

### Differential Fuzz Tests

```bash
# Run with default runs
forge test --match-contract ZeroMoonDifferentialTest

# Run with 100,000 fuzz runs
forge test --match-contract ZeroMoonDifferentialTest --fuzz-runs 100000
```

**What is Differential Testing?**
- Compares contract calculations vs an off-chain reference model
- Ensures on-chain math matches expected behavior
- Catches calculation errors that might not be caught by unit tests

## Test Coverage

### Unit Fuzz Tests (16 tests)

- `testFuzz_Buy` - Random buy amounts
- `testFuzz_Refund` - Random refund amounts
- `testFuzz_BuyClaimRefund` - Complex buy → claim → refund cycles
- `testFuzz_BackingNeverDecreases` - Economic invariant
- `testFuzz_TotalSupplyNeverExceeds` - Supply cap enforcement
- `testFuzz_RefundCalculationAccuracy` - View vs execution consistency
- `testFuzz_BuyerNoSelfDividends` - Dividend exploit prevention
- `testFuzz_MultipleUsersClaimDividends` - Multi-user dividend distribution
- `testFuzz_FeesDistributedCorrectly` - Fee allocation validation
- `testFuzz_CannotRefundMoreThanBalance` - Balance checks
- `testFuzz_MinimumRefundEnforced` - Minimum amount enforcement (deterministic)
- `testFuzz_TransferFeesApplied` - Transfer fee validation
- `testFuzz_BurningLimitReached` - Burning cap enforcement
- `testFuzz_ReserveFeeIncreasesAfterBurningLimit` - Fee structure changes
- `testFuzz_RapidTransfers` - Multiple sequential transfers
- `testFuzz_TransferUpdatesDividendTracking` - Dividend tracking on transfers

### Stateful Fuzz Tests (Invariants)

- `invariant_totalSupplyNeverExceeds` - Supply cap
- `invariant_ethAccounting` - ETH flow tracking
- `invariant_backingNeverDecreases` - Economic backing
- `invariant_burningLimit` - Burning cap
- `invariant_circulationSupply` - Circulation validation
- `invariant_tokensSold` - Sales tracking
- `invariant_dividendsMonotonic` - Dividends never decrease
- `invariant_userBalances` - User balance validation
- `invariant_solvency` - Contract solvency check
- `invariant_noBalanceExceedsSupply` - Balance bounds

### Differential Fuzz Tests (4 tests)

- `testFuzz_Differential_BuyCalculation` - Buy math vs reference
- `testFuzz_Differential_RefundCalculation` - Refund math vs reference
- `testFuzz_Differential_BuyFees` - Buy fees vs reference
- `testFuzz_Differential_RefundFees` - Refund fees vs reference

## Understanding Test Results

### Unit Fuzz Test Output

```
[PASS] testFuzz_Buy(uint256) (runs: 100000, μ: 154024, ~: 154128)
```

- `runs: 100000` - Number of random inputs tested
- `μ: 154024` - Mean gas usage
- `~: 154128` - Median gas usage

### Invariant Test Output

```
[PASS] invariant_backingNeverDecreases (runs: 10000, calls: 150000, reverts: 2341)
```

- `runs: 10000` - Number of invariant checks
- `calls: 150000` - Total function calls made
- `reverts: 2341` - Number of calls that reverted (expected for invalid states)

### Why `testFuzz_MinimumRefundEnforced` Only Runs Once?

This test is **deterministic**, not a fuzz test. It tests a specific fixed condition:
- "Can we refund less than 1 token?" (Answer: No, should revert)

There's no random input to fuzz - the test always checks the same scenario. This is intentional and correct - we want to verify the minimum refund enforcement with a deterministic test rather than random inputs.

The test name includes "Fuzz" for consistency with the test suite naming, but it's actually a deterministic unit test.

## Recommended Test Runs

### Development (Fast Feedback)
```bash
forge test --fuzz-runs 1000
```

### Pre-Deployment (Standard)
```bash
forge test --fuzz-runs 100000
FOUNDRY_PROFILE=ci forge test --match-contract ZeroMoonInvariantTest
```

### Comprehensive Audit (Maximum Coverage)
```bash
forge test --fuzz-runs 10000000
FOUNDRY_PROFILE=audit forge test --match-contract ZeroMoonInvariantTest
forge test --match-contract ZeroMoonDifferentialTest --fuzz-runs 100000
```

## Interpreting Results

### ✅ All Tests Pass
- Contract behavior matches expected invariants
- No calculation errors detected
- Ready for deployment

### ❌ Test Fails
- Review the counterexample provided by Foundry
- Check the specific invariant that failed
- Fix the issue and re-run tests

### ⚠️ High Gas Variance
- Large differences in gas usage may indicate inefficient code paths
- Review gas optimization opportunities

## Best Practices

1. **Run tests before every commit** - Catch issues early
2. **Increase fuzz runs before deployment** - More coverage = more confidence
3. **Review invariant failures carefully** - They indicate protocol-level issues
4. **Compare differential test results** - Ensures math correctness
5. **Monitor gas usage** - Consistent gas = predictable behavior

## Troubleshooting

### "Stack too deep" errors
- Reduce number of local variables in test functions
- Use inline calculations instead of storing intermediate values

### Tests timing out
- Reduce `--fuzz-runs` or `--invariant-runs`
- Reduce `--invariant-depth` for invariant tests

### Handler contract errors
- Ensure handler is excluded from fees in `setUp()`
- Check that actors have sufficient ETH/tokens for operations

## Additional Resources

- [Foundry Book - Fuzz Testing](https://book.getfoundry.sh/forge/fuzz-testing)
- [Foundry Book - Invariant Testing](https://book.getfoundry.sh/forge/invariant-testing)
- [ZeroMoon Fuzz Test Report](./FUZZ_TEST_REPORT.md)

