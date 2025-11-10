// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "forge-std/Test.sol";
import "../src/ZeroMoon.sol";

/**
 * @title ZeroMoonHandler
 * @notice Handler contract for stateful fuzzing (invariant testing)
 * @dev This handler allows Foundry to generate complex call sequences
 *      that test protocol-level invariants across multiple transactions
 */
contract ZeroMoonHandler is Test {
    ZeroMoon public token;
    
    // Track users for fuzzing
    address[] private _actors;
    mapping(address => bool) public isActor;
    
    function actors() external view returns (address[] memory) {
        return _actors;
    }
    
    function actors(uint256 index) external view returns (address) {
        return _actors[index];
    }
    
    // Track state for invariants
    uint256 public totalEthDeposited;
    uint256 public totalEthWithdrawn;
    uint256 public totalTokensBought;
    uint256 public totalTokensRefunded;
    
    // Constants matching contract
    uint256 public constant MIN_BUY = 0.0001 ether;
    uint256 public constant MIN_REFUND = 1 ether; // 1 zETH token
    uint256 public constant MAX_BUY = 100 ether;
    
    constructor(ZeroMoon _token) {
        token = _token;
        
        // Initialize with some actors
        _actors.push(address(0x1));
        _actors.push(address(0x2));
        _actors.push(address(0x3));
        _actors.push(address(0x4));
        _actors.push(address(0x5));
        
        for (uint256 i = 0; i < _actors.length; i++) {
            isActor[_actors[i]] = true;
            vm.deal(_actors[i], 1000 ether);
        }
    }
    
    /**
     * @notice Buy tokens - fuzzable action
     * @param actorIndex Index of actor (bounded to valid range)
     * @param ethAmount Amount of ETH to spend (bounded to valid range)
     */
    function buy(uint256 actorIndex, uint256 ethAmount) public {
        actorIndex = bound(actorIndex, 0, _actors.length - 1);
        address actor = _actors[actorIndex];
        ethAmount = bound(ethAmount, MIN_BUY, MAX_BUY);
        
        // Ensure actor has enough ETH
        if (actor.balance < ethAmount) {
            vm.deal(actor, ethAmount + 1 ether);
        }
        
        uint256 balanceBefore = token.balanceOf(actor);
        
        vm.prank(actor);
        token.buy{value: ethAmount}();
        
        // Track state
        totalEthDeposited += ethAmount;
        totalTokensBought += (token.balanceOf(actor) - balanceBefore);
        
        // Invariant: Actor should have tokens
        assertGt(token.balanceOf(actor), balanceBefore, "Buy should give tokens");
    }
    
    /**
     * @notice Refund tokens - fuzzable action
     * @param actorIndex Index of actor
     * @param zETHAmount Amount of zETH to refund (bounded to actor's balance)
     */
    function refund(uint256 actorIndex, uint256 zETHAmount) public {
        actorIndex = bound(actorIndex, 0, _actors.length - 1);
        address actor = _actors[actorIndex];
        
        uint256 actorBalance = token.balanceOf(actor);
        
        // Skip if actor doesn't have enough tokens
        if (actorBalance < MIN_REFUND) {
            return;
        }
        
        zETHAmount = bound(zETHAmount, MIN_REFUND, actorBalance);
        
        uint256 ethBefore = actor.balance;
        uint256 tokensBefore = token.balanceOf(actor);
        
        vm.prank(actor);
        token.transfer(address(token), zETHAmount); // Triggers refund
        
        // Track state
        totalEthWithdrawn += (actor.balance - ethBefore);
        totalTokensRefunded += (tokensBefore - token.balanceOf(actor));
        
        // Invariant: Actor should receive ETH
        assertGt(actor.balance, ethBefore, "Refund should give ETH");
    }
    
    /**
     * @notice Transfer tokens between actors - fuzzable action
     * @param fromIndex Index of sender
     * @param toIndex Index of recipient
     * @param amount Amount to transfer
     */
    function transfer(uint256 fromIndex, uint256 toIndex, uint256 amount) public {
        fromIndex = bound(fromIndex, 0, _actors.length - 1);
        toIndex = bound(toIndex, 0, _actors.length - 1);
        
        // Can't transfer to self
        if (fromIndex == toIndex) {
            return;
        }
        
        address from = _actors[fromIndex];
        address to = _actors[toIndex];
        
        uint256 fromBalance = token.balanceOf(from);
        
        // Skip if sender doesn't have enough (need at least 2 tokens for fees)
        if (fromBalance < 2 ether) {
            return;
        }
        
        amount = bound(amount, 1 ether, fromBalance / 2);
        
        uint256 toBalanceBefore = token.balanceOf(to);
        
        vm.prank(from);
        token.transfer(to, amount);
        
        // Invariant: Recipient should receive tokens (after fees)
        assertGt(token.balanceOf(to), toBalanceBefore, "Transfer should give tokens to recipient");
    }
    
    /**
     * @notice Claim dividends - fuzzable action
     * @param actorIndex Index of actor
     */
    function claimDividends(uint256 actorIndex) public {
        actorIndex = bound(actorIndex, 0, _actors.length - 1);
        address actor = _actors[actorIndex];
        
        uint256 balanceBefore = token.balanceOf(actor);
        uint256 pending = token.pendingDividends(actor);
        
        // Skip if no pending dividends
        if (pending == 0) {
            return;
        }
        
        vm.prank(actor);
        token.claimDividends();
        
        // Invariant: Actor should receive dividend tokens if pending
        if (pending > 0) {
            assertGe(token.balanceOf(actor), balanceBefore, "Claim should give dividend tokens");
        }
    }
    
    /**
     * @notice Complex operation: Buy → Claim → Refund sequence
     * @param actorIndex Index of actor
     * @param buyAmount Amount to buy
     * @param refundAmount Amount to refund
     */
    function buyClaimRefund(uint256 actorIndex, uint256 buyAmount, uint256 refundAmount) public {
        actorIndex = bound(actorIndex, 0, _actors.length - 1);
        address actor = _actors[actorIndex];
        
        buyAmount = bound(buyAmount, MIN_BUY, MAX_BUY);
        
        // Ensure actor has enough ETH
        if (actor.balance < buyAmount) {
            vm.deal(actor, buyAmount + 1 ether);
        }
        
        // Buy
        vm.prank(actor);
        token.buy{value: buyAmount}();
        
        uint256 tokens = token.balanceOf(actor);
        
        // Skip if not enough tokens
        if (tokens < MIN_REFUND) {
            return;
        }
        
        // Generate dividends (another actor buys)
        uint256 otherIndex = (actorIndex + 1) % _actors.length;
        address other = _actors[otherIndex];
        if (other.balance < MIN_BUY) {
            vm.deal(other, MIN_BUY + 1 ether);
        }
        vm.prank(other);
        token.buy{value: MIN_BUY}();
        
        // Claim
        vm.prank(actor);
        token.claimDividends();
        
        // Refund
        uint256 finalBalance = token.balanceOf(actor);
        if (finalBalance < MIN_REFUND) {
            return;
        }
        
        refundAmount = bound(refundAmount, MIN_REFUND, finalBalance);
        
        vm.prank(actor);
        token.transfer(address(token), refundAmount);
    }
    
    /**
     * @notice Get summary of handler state
     */
    function getSummary() external view returns (
        uint256 _totalEthDeposited,
        uint256 _totalEthWithdrawn,
        uint256 _totalTokensBought,
        uint256 _totalTokensRefunded,
        uint256 _contractBalance,
        uint256 _circulatingSupply
    ) {
        return (
            totalEthDeposited,
            totalEthWithdrawn,
            totalTokensBought,
            totalTokensRefunded,
            address(token).balance,
            token.getCirculatingSupplyPublic()
        );
    }
}

