# Fuzz Test Invariant Report

**Source file:** `invariant-maximum-20251107_151903.json` fileciteturn1file0

**Generated (UTC):** 2025-11-07T14:24:03.616895Z

## Executive summary

- **10** invariants tested.
- Aggregate runs: **10,000,000** (sum of reported per-invariant `runs`).
- Aggregate calls: **200,000,000**.
- Aggregate reverts: **110,938,433**.

## Per-invariant metrics

| Invariant | Runs | Calls | Reverts | Status |
|---|---:|---:|---:|---|
| invariant_backingNeverDecreases() | 1000000 | 20000000 | 11100745 | Success |
| invariant_burningLimit() | 1000000 | 20000000 | 11096213 | Success |
| invariant_circulationSupply() | 1000000 | 20000000 | 11087028 | Success |
| invariant_dividendsMonotonic() | 1000000 | 20000000 | 11089926 | Success |
| invariant_ethAccounting() | 1000000 | 20000000 | 11090111 | Success |
| invariant_noBalanceExceedsSupply() | 1000000 | 20000000 | 11088430 | Success |
| invariant_solvency() | 1000000 | 20000000 | 11100790 | Success |
| invariant_tokensSold() | 1000000 | 20000000 | 11086445 | Success |
| invariant_totalSupplyNeverExceeds() | 1000000 | 20000000 | 11098803 | Success |
| invariant_userBalances() | 1000000 | 20000000 | 11099942 | Success |

## Top functions by total reverts (across invariants)

| Function | Calls | Reverts |
|---|---:|---:|
| src/ZeroMoon.sol:ZeroMoon.transferOwnership | 11,116,184 | 11,115,900 |
| src/ZeroMoon.sol:ZeroMoon.acceptOwnership | 11,111,098 | 11,111,098 |
| src/ZeroMoon.sol:ZeroMoon.setDevAddress | 11,110,711 | 11,110,405 |
| src/ZeroMoon.sol:ZeroMoon.excludeFromFee | 11,110,627 | 11,110,333 |
| src/ZeroMoon.sol:ZeroMoon.transfer | 11,110,160 | 11,109,871 |
| src/ZeroMoon.sol:ZeroMoon.renounceOwnership | 11,110,080 | 11,109,819 |
| src/ZeroMoon.sol:ZeroMoon.transferFrom | 11,106,792 | 11,106,792 |
| src/ZeroMoon.sol:ZeroMoon.permit | 11,106,497 | 11,106,497 |
| src/ZeroMoon.sol:ZeroMoon.buy | 11,105,291 | 11,105,291 |
| src/ZeroMoon.sol:ZeroMoon.decreaseAllowance | 11,115,028 | 10,928,784 |

## Observations & recommended next steps

1. Functions with the highest revert counts (above) are the best starting point for debugging — inspect input validations, require/requireFalse conditions, and boundary arithmetic.
2. If you want a prioritized action list, I can generate one (e.g., top 5 functions by revert ratio `reverts/calls`).
3. I can also export the per-invariant table as CSV/Excel for sharing with auditors.
