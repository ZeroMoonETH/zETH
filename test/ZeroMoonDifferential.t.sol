// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "forge-std/Test.sol";
import "../src/ZeroMoon.sol";

/**
 * @title ZeroMoonDifferentialTest
 * @notice Differential fuzzing: compares contract behavior vs reference model
 * @dev Tests that on-chain calculations match off-chain reference implementation
 * 
 * Run with: forge test --match-contract ZeroMoonDifferentialTest --fuzz-runs 100000
 */
contract ZeroMoonDifferentialTest is Test {
    ZeroMoon public token;
    address public owner;
    address public dev;
    address public user1;
    
    uint256 public constant INITIAL_ETH = 10 ether;
    
    // Reference model constants (matching contract)
    uint256 private constant BASE_PRICE = 0.0001 ether;
    uint256 private constant PRECISION_DIVISOR = 10000;
    uint256 private constant EFFECTIVE_BACKING_NUMERATOR = 999;
    uint256 private constant EFFECTIVE_BACKING_DENOMINATOR = 1000;
    
    // Fee constants
    uint256 private constant BUY_DEV_FEE_BPS = 5;
    uint256 private constant BUY_RESERVE_FEE_BPS = 10;
    uint256 private constant BUY_REFLECTION_FEE_BPS = 10;
    
    uint256 private constant REFUND_DEV_FEE_BPS = 5;
    uint256 private constant REFUND_REFLECTION_FEE_BPS = 5;
    uint256 private constant REFUND_BURN_FEE_BPS = 75; // 0.75% = 75/10000
    uint256 private constant REFUND_RESERVE_FEE_BPS_BEFORE_LIMIT = 75;
    uint256 private constant REFUND_RESERVE_FEE_BPS_AFTER_LIMIT = 150;
    
    function setUp() public {
        owner = address(this);
        dev = address(0x123);
        user1 = address(0x456);
        
        vm.deal(owner, 1000 ether);
        vm.deal(user1, 100 ether);
        
        token = new ZeroMoon{value: INITIAL_ETH}(owner, dev);
    }
    
    /**
     * @notice Reference model: Calculate zETH for native (off-chain simulation)
     * @dev Replicates contract's _getzETHForNative logic
     */
    function reference_getzETHForNative(
        uint256 nativeAmount,
        uint256 contractBalance,
        uint256 totalSupply,
        uint256 contractTokenBalance
    ) private pure returns (uint256) {
        if (nativeAmount == 0) return 0;
        if (contractTokenBalance == 0) return 0;
        
        uint256 circulating = totalSupply - contractTokenBalance;
        
        uint256 pricePerToken;
        if (circulating == 0 || contractBalance == 0) {
            pricePerToken = BASE_PRICE;
        } else {
            uint256 refundPrice = (contractBalance * 1e18) / circulating;
            pricePerToken = (refundPrice * 10010) / PRECISION_DIVISOR;
        }
        
        uint256 tokensToPurchase = (nativeAmount * 1e18) / pricePerToken;
        return tokensToPurchase < contractTokenBalance ? tokensToPurchase : contractTokenBalance;
    }
    
    /**
     * @notice Reference model: Calculate fees for buy
     * @dev Replicates contract's fee calculation logic
     */
    function reference_calculateBuyFees(uint256 zETHAmount) private pure returns (
        uint256 devFee,
        uint256 reserveFee,
        uint256 reflectionFee,
        uint256 netAmount
    ) {
        devFee = (zETHAmount * BUY_DEV_FEE_BPS) / 10000;
        reserveFee = (zETHAmount * BUY_RESERVE_FEE_BPS) / 10000;
        reflectionFee = (zETHAmount * BUY_REFLECTION_FEE_BPS) / 10000;
        
        unchecked {
            netAmount = zETHAmount - devFee - reserveFee - reflectionFee;
        }
    }
    
    /**
     * @notice Reference model: Calculate fees for refund
     * @dev Replicates contract's refund fee calculation logic
     */
    function reference_calculateRefundFees(
        uint256 zETHAmount,
        uint256 totalBurned,
        uint256 burningLimit
    ) private pure returns (
        uint256 devFee,
        uint256 reflectionFee,
        uint256 burnFee,
        uint256 reserveFee,
        uint256 netAmount
    ) {
        devFee = (zETHAmount * REFUND_DEV_FEE_BPS) / 10000;
        reflectionFee = (zETHAmount * REFUND_REFLECTION_FEE_BPS) / 10000;
        
        if (totalBurned < burningLimit) {
            burnFee = (zETHAmount * REFUND_BURN_FEE_BPS) / 100000;
            reserveFee = (zETHAmount * REFUND_RESERVE_FEE_BPS_BEFORE_LIMIT) / 100000;
        } else {
            burnFee = 0;
            reserveFee = (zETHAmount * REFUND_RESERVE_FEE_BPS_AFTER_LIMIT) / 100000;
        }
        
        unchecked {
            netAmount = zETHAmount - devFee - reflectionFee - burnFee - reserveFee;
        }
    }
    
    /**
     * @notice Reference model: Calculate native refund for zETH
     * @dev Replicates contract's calculateNativeForZETH logic
     */
    function reference_calculateNativeForZETH(
        uint256 zETHAmount,
        uint256 contractBalance,
        uint256 totalSupply,
        uint256 totalBurned,
        uint256 contractTokenBalance,
        uint256 burningLimit
    ) private pure returns (uint256) {
        if (zETHAmount == 0) return 0;
        if (zETHAmount < 1 ether) return 0; // Minimum refund
        
        // Calculate fees
        (uint256 devFee, uint256 reflectionFee, uint256 burnFee, uint256 reserveFee, uint256 netAmount) =
            reference_calculateRefundFees(zETHAmount, totalBurned, burningLimit);
        
        uint256 currentCirculatingSupply = (totalSupply - totalBurned) - contractTokenBalance + zETHAmount;
        
        if (currentCirculatingSupply == 0) return 0;
        
        uint256 effectiveBacking = (contractBalance * EFFECTIVE_BACKING_NUMERATOR) / EFFECTIVE_BACKING_DENOMINATOR;
        
        // Use mulDiv equivalent (simplified for reference)
        uint256 nativeToUser = (netAmount * effectiveBacking) / currentCirculatingSupply;
        
        return nativeToUser;
    }
    
    /**
     * @notice DIFFERENTIAL TEST: Buy calculation matches reference model
     * @dev Compares contract's buy calculation vs off-chain reference
     */
    function testFuzz_Differential_BuyCalculation(uint256 ethAmount) public {
        ethAmount = bound(ethAmount, 0.0001 ether, 10 ether);
        
        // Get contract state
        uint256 contractBalance = address(token).balance;
        uint256 totalSupply = token.totalSupply();
        uint256 contractTokenBalance = token.balanceOf(address(token));
        
        // Reference calculation
        uint256 referenceTokens = reference_getzETHForNative(
            ethAmount,
            contractBalance,
            totalSupply,
            contractTokenBalance
        );
        
        // Contract calculation
        uint256 contractTokens = token.calculatezETHForNative(ethAmount);
        
        // Allow 1 wei tolerance for rounding differences
        assertApproxEqAbs(
            contractTokens,
            referenceTokens,
            1,
            "Contract buy calculation should match reference model"
        );
    }
    
    /**
     * @notice DIFFERENTIAL TEST: Refund calculation matches reference model
     * @dev Compares contract's refund calculation vs off-chain reference
     */
    function testFuzz_Differential_RefundCalculation(uint256 zETHAmount) public {
        // First, buy some tokens
        vm.prank(user1);
        token.buy{value: 1 ether}();
        
        uint256 userBalance = token.balanceOf(user1);
        
        // Skip if not enough tokens
        if (userBalance < 1 ether) {
            return;
        }
        
        zETHAmount = bound(zETHAmount, 1 ether, userBalance);
        
        // Get contract state
        uint256 contractBalance = address(token).balance;
        uint256 totalSupply = token.totalSupply();
        uint256 totalBurned = token.totalBurned();
        uint256 contractTokenBalance = token.balanceOf(address(token));
        uint256 burningLimit = token.BURNING_LIMIT();
        
        // Reference calculation
        uint256 referenceRefund = reference_calculateNativeForZETH(
            zETHAmount,
            contractBalance,
            totalSupply,
            totalBurned,
            contractTokenBalance,
            burningLimit
        );
        
        // Contract calculation
        uint256 contractRefund = token.calculateNativeForZETH(zETHAmount);
        
        // Allow 1% tolerance for rounding differences in mulDiv
        uint256 tolerance = referenceRefund / 100;
        if (tolerance < 1000 wei) tolerance = 1000 wei;
        
        assertApproxEqAbs(
            contractRefund,
            referenceRefund,
            tolerance,
            "Contract refund calculation should match reference model"
        );
    }
    
    /**
     * @notice DIFFERENTIAL TEST: Buy fees match reference model
     * @dev Compares actual buy fees vs reference calculation
     */
    function testFuzz_Differential_BuyFees(uint256 ethAmount) public {
        ethAmount = bound(ethAmount, 0.0001 ether, 10 ether);
        
        // Calculate expected tokens
        uint256 zETHToPurchase = token.calculatezETHForNative(ethAmount);
        
        if (zETHToPurchase == 0) {
            return;
        }
        
        // Reference fee calculation
        (uint256 refDevFee, uint256 refReserveFee, uint256 refReflectionFee, uint256 refNetAmount) =
            reference_calculateBuyFees(zETHToPurchase);
        
        // Execute buy
        uint256 userBalanceBefore = token.balanceOf(user1);
        uint256 devBalanceBefore = token.balanceOf(dev);
        
        vm.prank(user1);
        token.buy{value: ethAmount}();
        
        // Calculate actual fees
        uint256 userReceived = token.balanceOf(user1) - userBalanceBefore;
        uint256 devReceived = token.balanceOf(dev) - devBalanceBefore;
        
        // Compare net amount (allow 1 wei tolerance)
        assertApproxEqAbs(
            userReceived,
            refNetAmount,
            1,
            "User should receive net amount matching reference"
        );
        
        // Compare dev fee (allow 1 wei tolerance)
        assertApproxEqAbs(
            devReceived,
            refDevFee,
            1,
            "Dev fee should match reference"
        );
    }
    
    /**
     * @notice DIFFERENTIAL TEST: Refund fees match reference model
     * @dev Compares actual refund fees vs reference calculation
     */
    function testFuzz_Differential_RefundFees(uint256 zETHAmount) public {
        // Buy tokens first
        vm.prank(user1);
        token.buy{value: 1 ether}();
        
        uint256 userBalance = token.balanceOf(user1);
        
        if (userBalance < 1 ether) {
            return;
        }
        
        zETHAmount = bound(zETHAmount, 1 ether, userBalance);
        
        // Get state
        uint256 totalBurned = token.totalBurned();
        uint256 burningLimit = token.BURNING_LIMIT();
        
        // Reference fee calculation
        (uint256 refDevFee, uint256 refReflectionFee, uint256 refBurnFee, uint256 refReserveFee, uint256 refNetAmount) =
            reference_calculateRefundFees(zETHAmount, totalBurned, burningLimit);
        
        // Execute refund
        uint256 userEthBefore = user1.balance;
        uint256 devBalanceBefore = token.balanceOf(dev);
        uint256 totalBurnedBefore = token.totalBurned();
        
        vm.prank(user1);
        token.transfer(address(token), zETHAmount);
        
        // Calculate actual results
        uint256 userEthReceived = user1.balance - userEthBefore;
        uint256 devReceived = token.balanceOf(dev) - devBalanceBefore;
        uint256 totalBurnedAfter = token.totalBurned();
        uint256 actualBurned = totalBurnedAfter - totalBurnedBefore;
        
        // Compare dev fee (allow 1 wei tolerance)
        assertApproxEqAbs(
            devReceived,
            refDevFee,
            1,
            "Dev fee should match reference"
        );
        
        // Compare burn fee (allow 1 wei tolerance, but only if under limit)
        if (totalBurnedBefore < burningLimit) {
            assertApproxEqAbs(
                actualBurned,
                refBurnFee,
                1,
                "Burn fee should match reference"
            );
        } else {
            assertEq(actualBurned, 0, "No burn after limit");
        }
    }
}

