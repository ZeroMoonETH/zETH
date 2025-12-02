# GitHub Repository Structure Guide

This document provides a comprehensive guide for structuring the ZeroMoon zETH repository for open-source release.

---

## 📁 Complete Directory Structure

```
zeromoon-zeth/
│
├── .github/
│   ├── workflows/
│   │   └── ci.yml                          # GitHub Actions CI/CD
│   ├── ISSUE_TEMPLATE/
│   │   ├── bug_report.md                   # Bug report template
│   │   ├── feature_request.md              # Feature request template
│   │   └── security_report.md              # Security report template
│   └── PULL_REQUEST_TEMPLATE.md            # PR template
│
├── ZEROMOON/
│   └── src/
│       └── lib/
│           ├── ZeroMoon.sol                # Main production contract (857 lines)
│           └── ZeroMoon_Fuzz.sol           # Testing version (optional reference)
│
├── test/
│   ├── ZeroMoonFuzz.t.sol                  # Unit fuzz tests (16 tests)
│   ├── ZeroMoonInvariant.t.sol             # Invariant tests (10 invariants)
│   ├── ZeroMoonHandler.sol                 # Handler for invariant campaigns
│   ├── ZeroMoonDifferential.t.sol          # Differential tests (4 tests)
│   │
│   ├── FUZZ_TEST_REPORT.md                 # 160M+ unit fuzz results
│   ├── INVARIANT_TEST_REPORT.md            # 200M+ invariant results
│   ├── COMPREHENSIVE_TEST_REPORT.md        # Combined 360M+ analysis
│   ├── FUZZ_TESTING_GUIDE.md               # How to run tests
│   ├── ENHANCEMENTS_SUMMARY.md             # Test architecture overview
│   │
│   ├── run-maximum-tests.sh                # Linux/Mac: sequential execution
│   ├── run-both-parallel.sh                # Linux/Mac: parallel execution
│   ├── run-both-sequential.sh              # Linux/Mac: alternative sequential
│   ├── run-invariant-only.sh               # Linux/Mac: invariants only
│   ├── run-maximum-tests.ps1               # Windows PowerShell version
│   ├── run-invariant-safe.sh               # Safe mode for memory constraints
│   │
│   └── test-results/                       # Sample test outputs
│       ├── fuzz-maximum-sample.json        # Sample unit fuzz logs
│       ├── invariant-maximum-sample.json   # Sample invariant logs
│       └── README.md                       # Explanation of logs
│
├── certora/
│   └── zeth/
│       ├── README.md                       # Certora verification overview
│       ├── CERTORA_AUDIT_REPORT.md         # Comprehensive audit report
│       ├── GAME_THEORY_ANALYSIS.md        # Attack vector analysis
│       ├── STRESS_TEST_REPORT.md           # Extreme scenario testing
│       ├── DESIGN_RATIONALE.md             # Comparison with failed projects
│       ├── EXECUTIVE_SUMMARY.md            # High-level summary
│       ├── QUICK_REFERENCE.md              # Quick verification stats
│       ├── VIOLATIONS_DETAILED.md          # Detailed violation analysis
│       ├── zeth-comprehensive.spec         # Main Certora specification
│       ├── zeth-improved.spec              # Improved spec with ghost variables
│       ├── zeth.spec                       # Basic specification
│       ├── certora.conf                    # Certora configuration
│       ├── run-maximum-certora.sh          # Maximum verification script
│       ├── run-basic-certora.sh             # Basic verification script
│       └── src/
│           └── ZeroMoon.sol                # Contract source code
│
├── script/
│   ├── Deploy.s.sol                        # Main deployment script
│   ├── DeployTestnet.s.sol                 # Testnet deployment
│   └── Verify.s.sol                        # Contract verification script
│
├── lib/                                    # Git submodules (auto-generated)
│   ├── forge-std/                          # Foundry standard library
│   └── openzeppelin-contracts/             # OpenZeppelin contracts v4.9.3
│
├── docs/                                   # Additional documentation
│   ├── ARCHITECTURE.md                     # Contract architecture
│   ├── FEE_STRUCTURE.md                    # Detailed fee breakdown
│   ├── DIVIDEND_MECHANISM.md               # Dividend system explanation
│   └── DEPLOYMENT_GUIDE.md                 # Step-by-step deployment
│
├── .gitignore                              # Git ignore file
├── .gitmodules                             # Git submodules config
├── foundry.toml                            # Foundry configuration
├── remappings.txt                          # Import remappings (optional)
│
├── README.md                               # Main project documentation
├── SECURITY.md                             # Security policy and audit results
├── IMMUTABILITY.md                         # Contract renouncement explanation
├── LICENSE                                 # MIT License
├── CHANGELOG.md                            # Version history
└── REPOSITORY_STRUCTURE.md                 # This file
```

---

## 📝 Key Files Overview

### Root Level
- **README.md** - Main project documentation
- **SECURITY.md** - Security policy and audit results
- **IMMUTABILITY.md** - Contract renouncement explanation
- **CHANGELOG.md** - Version history
- **LICENSE** - MIT License
- **foundry.toml** - Foundry configuration

### Testing
- **test/** - Foundry test suite (360M+ test cases)
- **certora/zeth/** - Certora formal verification (14 properties verified)

### Contract
- **ZEROMOON/src/lib/ZeroMoon.sol** - Main production contract

### Scripts
- **script/** - Deployment and verification scripts

---

**Last Updated:** December 1, 2025
  
