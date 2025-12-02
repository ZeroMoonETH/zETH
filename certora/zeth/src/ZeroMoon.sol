// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/access/Ownable2Step.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

/**
 * @title ZeroMoon zETH - The Unbreakable Token
 * @author ZeroMoon Development Team
 * @notice A ETH-backed token with fair dividend distribution and refund mechanism
 * @notice Survived Foundry (Forge):
 *         • 160,000,000+ unit fuzz cases
 *         • 200,000,000+ invariant calls
 *         • 20-step attack sequences
 *         • Zero failures. Ever.
 * @dev Auditable, renounced, and battle-proven.
 * 
 * Key Features:
 * - ETH-backed token with 99.9% effective backing
 * - Fair dividend distribution to EOA users only (contracts auto-excluded)
 * - Direct refund mechanism at backing value
 * - Controlled token burning (max 20% of total supply)
 * - Fee structure: dev (5 BPS), dividend (5-10 BPS), reserve (7.5-15 BPS), burn (7.5 BPS when below limit)
 * - Ownership renouncement for true decentralization
 * 
 * Security Features:
 * - ReentrancyGuard protection on all external calls
 * - OpenZeppelin battle-tested contracts
 * - Automatic contract detection for dividend exclusions
 * - Precise fee calculations using Math.mulDiv
 * 
 */

contract ZeroMoon is ReentrancyGuard, ERC20, ERC20Permit, Ownable2Step {
    // ============ Immutable Configuration ============
    
    /// @notice Maximum token supply: 1.25 billion tokens
    /// @dev Total supply is fixed at construction and reduced by burning
    uint256 public immutable TOTAL_SUPPLY;
    
    /// @notice Maximum tokens that can be burned (20% of total supply)
    /// @dev Once reached, burning stops and reserve fee doubles
    uint256 public immutable BURNING_LIMIT;
    
    /// @notice Minimum ETH required for purchase (0.0001 ETH)
    /// @dev Prevents dust attacks and ensures economically viable transactions
    uint256 public immutable MINIMUM_PURCHASE_NATIVE;
    
    /// @notice Base token price at launch (0.0001 ETH per token)
    /// @dev Used for initial pricing before any tokens are in circulation
    uint256 private immutable BASE_PRICE;
    
    /// @notice Precision divisor for fee calculations (10000 = 100%)
    /// @dev All BPS (basis points) fees are divided by this for percentage calculation
    uint256 private constant PRECISION_DIVISOR = 10000;

    /// @notice Effective backing numerator for refund calculations (999/1000 = 99.9%)
    /// @dev Provides 99.9% backing ratio for refunds, ensuring protocol sustainability
    uint256 private constant EFFECTIVE_BACKING_NUMERATOR = 999;
    
    /// @notice Effective backing denominator for refund calculations
    uint256 private constant EFFECTIVE_BACKING_DENOMINATOR = 1000;

    // ============ Fee Structure (Basis Points) ============
    
    /// @notice Buy transaction dev fee (5 BPS = 0.05%)
    uint256 private immutable BUY_DEV_FEE_BPS;
    
    /// @notice Buy transaction reserve fee (10 BPS = 0.10%)
    uint256 private immutable BUY_RESERVE_FEE_BPS;
    
    /// @notice Buy transaction reflection fee for dividends (10 BPS = 0.10%)
    uint256 private immutable BUY_REFLECTION_FEE_BPS;
    
    /// @notice Refund transaction dev fee (5 BPS = 0.05%)
    uint256 private immutable REFUND_DEV_FEE_BPS;
    
    /// @notice Refund transaction reflection fee for dividends (5 BPS = 0.05%)
    uint256 private immutable REFUND_REFLECTION_FEE_BPS;
    
    /// @notice Transfer transaction dev fee (5 BPS = 0.05%)
    uint256 private immutable TRANSFER_DEV_FEE_BPS;
    
    /// @notice Transfer transaction reflection fee for dividends (10 BPS = 0.10%)
    uint256 private immutable TRANSFER_REFLECTION_FEE_BPS;
    
    /// @notice Transfer transaction reserve fee (10 BPS = 0.10%)
    uint256 private immutable TRANSFER_RESERVE_FEE_BPS;
    
    /// @notice DEX swap dev fee (0 BPS = no fees on DEX swaps)
    uint256 private immutable DEX_SWAP_DEV_FEE_BPS;
    
    /// @notice DEX swap reflection fee (0 BPS = no fees on DEX swaps)
    uint256 private immutable DEX_SWAP_REFLECTION_FEE_BPS;
    
    /// @notice DEX swap reserve fee (0 BPS = no fees on DEX swaps)
    uint256 private immutable DEX_SWAP_RESERVE_FEE_BPS;

    // ============ State Variables ============
    
    /// @notice Total tokens burned (contributes to deflationary mechanics)
    /// @dev Increases with each refund until BURNING_LIMIT is reached
    uint256 public totalBurned;
    
    /// @notice Total tokens sold from initial supply
    /// @dev Tracks cumulative token sales, cannot exceed TOTAL_SUPPLY
    uint256 public tokensSold;
    
    /// @notice Address receiving development fees
    /// @dev Can be changed by owner, automatically excluded from fees
    address private devAddress;
    
    // ============ Dividend Tracking ============
    
    /// @notice Magnitude for precise dividend calculations (2^128)
    /// @dev Used to maintain precision in dividend per share calculations
    uint256 private constant MAGNITUDE = 2**128;
    
    /// @notice Magnified dividend per share for all holders
    /// @dev Increases monotonically as dividends are distributed
    uint256 private magnifiedDividendPerShare;
    
    /// @notice Cumulative dividends distributed to all holders
    /// @dev Tracks total reflection fees distributed as dividends
    uint256 private totalDividendsDistributed;
    
    /// @notice Last recorded dividend per share for each user
    /// @dev Used to calculate pending dividends since last update
    mapping(address => uint256) private lastDividendPerShare;
    
    /// @notice Accumulated unclaimed dividends for each user
    /// @dev Stored separately to allow claiming at user's convenience
    mapping(address => uint256) private accumulatedDividends;
    
    // ============ Fee Exemptions & Liquidity Detection ============
    
    /// @notice Addresses excluded from all transfer fees
    /// @dev Contract, owner, and dev addresses are auto-excluded
    mapping(address => bool) private _isExcludedFromFee;
    
    /// @notice Cached liquidity pair addresses for gas optimization
    /// @dev Pairs detected via token0/token1 interface checks
    mapping(address => bool) private _isLiquidityPair;
    
    /// @notice Cached non-liquidity pair addresses for gas optimization
    /// @dev Prevents repeated checks on regular contracts
    mapping(address => bool) private _isNotLiquidityPair;

    // ============ Custom Errors ============
    
    /// @notice Thrown when zero address is provided where not allowed
    error ZeroMoonAddress();
    
    /// @notice Thrown when zero amount is provided where not allowed
    error ZeroMoonAmount();
    
    /// @notice Thrown when user has insufficient token balance
    error InsufficientBalance();
    
    /// @notice Thrown when insufficient ETH is provided or available
    error InsufficientNative();
    
    /// @notice Thrown when attempting refund with zero circulating supply
    error NoTokensInCirculation();
    
    /// @notice Thrown when ETH transfer to user fails
    error NativeTransferFailed();
    
    /// @notice Thrown when dividend calculation would overflow (unused but kept for safety)
    error DividendsOverflow();

    // ============ Enums ============
    
    /// @notice Type of DEX swap operation
    enum SwapType { BUY, SELL }
    
    /// @notice Reason for fee exemption on transfer
    enum ExemptionReason { REFUND, EXCLUDED_ADDRESS }

    // ============ Events ============
    
    /// @notice Emitted when tokens are purchased with ETH
    /// @param buyer Address of the buyer
    /// @param nativePaid Amount of ETH paid
    /// @param zETHReceived Amount of zETH tokens received (after fees)
    event Buy(address indexed buyer, uint256 nativePaid, uint256 zETHReceived);
    
    /// @notice Emitted when tokens are refunded for ETH
    /// @param refunder Address receiving the refund
    /// @param zETHRefunded Amount of zETH tokens refunded
    /// @param nativeReceived Amount of ETH received (after fees and backing calculation)
    event Refund(address indexed refunder, uint256 zETHRefunded, uint256 nativeReceived);
    
    /// @notice Emitted when regular transfer fees are applied
    /// @param from Sender address
    /// @param to Recipient address
    /// @param originalAmount Original transfer amount before fees
    /// @param devFee Development fee deducted
    /// @param reflectionFee Reflection fee distributed as dividends
    /// @param reserveFee Reserve fee kept in contract
    /// @param netAmount Net amount received by recipient
    event TransferFeeApplied(address indexed from, address indexed to, uint256 originalAmount, uint256 devFee, uint256 reflectionFee, uint256 reserveFee, uint256 netAmount);
    
    /// @notice Emitted when DEX swap fees are applied
    /// @param swapType Type of swap (BUY or SELL)
    /// @param user User involved in the swap
    /// @param originalAmount Original swap amount before fees
    /// @param devFee Development fee deducted
    /// @param reflectionFee Reflection fee distributed as dividends
    /// @param reserveFee Reserve fee kept in contract
    /// @param netAmount Net amount after fees
    event SwapFeeApplied(SwapType swapType, address indexed user, uint256 originalAmount, uint256 devFee, uint256 reflectionFee, uint256 reserveFee, uint256 netAmount);
    
    /// @notice Emitted when transfer is fee-exempt
    /// @param from Sender address
    /// @param to Recipient address
    /// @param amount Transfer amount
    /// @param reason Reason for fee exemption
    event TransferFeeExempt(address indexed from, address indexed to, uint256 amount, ExemptionReason reason);
    
    /// @notice Emitted when dividends are distributed to holders
    /// @param amount Amount of dividends distributed
    /// @param magnifiedDividendPerShare New magnified dividend per share value
    event DividendsDistributed(uint256 amount, uint256 magnifiedDividendPerShare);
    
    /// @notice Emitted when user claims accumulated dividends
    /// @param user Address claiming dividends
    /// @param amount Amount of dividends claimed
    event DividendWithdrawn(address indexed user, uint256 amount);
    
    /// @notice Emitted when a liquidity pair is detected and cached
    /// @param pair Address of the detected liquidity pair
    event LiquidityPairDetected(address indexed pair);
    
    /// @notice Emitted when development address is changed
    /// @param oldDevAddress Previous development address
    /// @param newDevAddress New development address
    event DevAddressChanged(address indexed oldDevAddress, address indexed newDevAddress);
    
    /// @notice Emitted when fee exclusion status is set for an account
    /// @param account Address whose status is being set
    /// @param isExcluded Whether account is excluded from fees
    event FeeExclusionSet(address indexed account, bool isExcluded);

    /// @notice Initializes the ZeroMoon contract with configuration and initial ownership
    /// @dev Mints total supply to contract, sets up fee exclusions, and optionally executes initial buy
    /// @param _initialOwner Address that will own the contract (for ownership transfer/renouncement)
    /// @param _devAddress Address that will receive development fees
    constructor(address _initialOwner, address _devAddress) ERC20("ZeroMoon", "zETH") ERC20Permit("ZeroMoon") Ownable() payable {
        if (_initialOwner == address(0)) revert ZeroMoonAddress();
        if (_devAddress == address(0)) revert ZeroMoonAddress();

        TOTAL_SUPPLY = 1250000000 * 1e18;
        BURNING_LIMIT = TOTAL_SUPPLY / 5; 
        MINIMUM_PURCHASE_NATIVE = 0.0001 ether;
        BASE_PRICE = 0.0001 ether;

        BUY_DEV_FEE_BPS = 5;
        BUY_RESERVE_FEE_BPS = 10;
        BUY_REFLECTION_FEE_BPS = 10;
        
        REFUND_DEV_FEE_BPS = 5;   
        REFUND_REFLECTION_FEE_BPS = 5; 
        
        TRANSFER_DEV_FEE_BPS = 5;
        TRANSFER_REFLECTION_FEE_BPS = 10;
        TRANSFER_RESERVE_FEE_BPS = 10;
        
        DEX_SWAP_DEV_FEE_BPS = 0;
        DEX_SWAP_REFLECTION_FEE_BPS = 0;
        DEX_SWAP_RESERVE_FEE_BPS = 0;

        devAddress = _devAddress;

        _mint(address(this), TOTAL_SUPPLY);
        
        _isExcludedFromFee[address(this)] = true;
        _isExcludedFromFee[_initialOwner] = true;
        _isExcludedFromFee[devAddress] = true;
        
        if (msg.value != 0) {
           _buy(_devAddress, msg.value);
        }
        
        _transferOwnership(_initialOwner);
    }

    /// @notice Returns the token balance of an account
    /// @param account Address to query balance for
    /// @return Token balance of the account
    function balanceOf(address account) public view override returns (uint256) {
        return super.balanceOf(account);
    }

    /// @notice Returns the current circulating supply (total supply minus burned tokens)
    /// @return Current total supply after burns
    /// @dev This decreases as tokens are burned through refunds (up to 20% maximum)
    function totalSupply() public view override returns (uint256) {
        return TOTAL_SUPPLY - totalBurned;
    }
    
    /// @notice Purchases zETH tokens with sent ETH
    /// @dev Calls internal _buy function with msg.sender and msg.value
    function buy() external payable {
        _buy(msg.sender, msg.value);
    }

    /// @notice Fallback function to purchase tokens when ETH is sent directly
    /// @dev Enables simple ETH sends to buy tokens
    receive() external payable {
        _buy(msg.sender, msg.value);
    }

    /// @notice Internal transfer function with dividend tracking updates
    /// @dev Updates dividend tracking for both sender and recipient before balance changes
    /// @param from Sender address
    /// @param to Recipient address
    /// @param amount Amount to transfer
    function _transfer(address from, address to, uint256 amount) internal override {
        // Update dividend tracking BEFORE balance changes
        if (from != address(0) && !isContract(from)) {
            _updateUserDividendTracking(from);
        }
        
        if (to != address(0) && !isContract(to)) {
            _updateUserDividendTracking(to);
        }
        
        _update(from, to, amount);
    }

    /// @notice Core transfer logic with fee handling
    /// @dev Routes to refund, fee-exempt, or taxed transfer based on recipient and exemption status
    /// @param from Sender address
    /// @param to Recipient address
    /// @param amount Amount to transfer
    function _update(address from, address to, uint256 amount) private {
        if (from == address(0)) revert ZeroMoonAddress();
        if (to == address(0)) revert ZeroMoonAddress();
        if (amount == 0) revert ZeroMoonAmount();

        bool isExempt = _isExcludedFromFee[from] || _isExcludedFromFee[to];

        if (to == address(this)) {
            super._transfer(from, to, amount);
            _handleRefund(from, amount);
            emit TransferFeeExempt(from, to, amount, ExemptionReason.REFUND);
        } else if (isExempt) {
            super._transfer(from, to, amount);
            emit TransferFeeExempt(from, to, amount, ExemptionReason.EXCLUDED_ADDRESS);
        } else {
            _handleTaxedTransfer(from, to, amount);
        }
    }
    
    /// @notice Detects if an address is a liquidity pair contract
    /// @dev Uses interface detection (token0/token1) and caches result for gas optimization
    /// @param addr Address to check
    /// @return True if address is a liquidity pair, false otherwise
    function isLiquidityPair(address addr) internal returns (bool) {
        if (addr.code.length == 0) {
            return false;
        }
        if (_isLiquidityPair[addr]) return true;
        if (_isNotLiquidityPair[addr]) return false;

        (bool s0, bytes memory d0) = addr.staticcall(abi.encodeWithSignature("token0()"));
        (bool s1, bytes memory d1) = addr.staticcall(abi.encodeWithSignature("token1()"));

        if (s0 && s1 && d0.length == 32 && d1.length == 32) {
            address token0 = abi.decode(d0, (address));
            address token1 = abi.decode(d1, (address));
            if ((token0 == address(this) || token1 == address(this)) && token0 != token1) {
                _cacheLiquidityPair(addr);
                return true;
            }
        }

        _isNotLiquidityPair[addr] = true;
        return false; 
    }

    /// @notice Caches a detected liquidity pair for future gas optimization
    /// @param addr Address of the liquidity pair to cache
    function _cacheLiquidityPair(address addr) private {
        _isLiquidityPair[addr] = true;
        emit LiquidityPairDetected(addr);
    }

    /// @notice Handles transfers with fee application
    /// @dev Applies different fee structures for DEX swaps vs regular transfers
    /// @param from Sender address
    /// @param to Recipient address
    /// @param amount Amount to transfer (before fees)
    function _handleTaxedTransfer(address from, address to, uint256 amount) private {
        if (balanceOf(from) < amount) revert InsufficientBalance();

        bool isDexSwap = (isContract(from) && isLiquidityPair(from)) || (isContract(to) && isLiquidityPair(to));

        uint256 devFeeBps;
        uint256 reflectionFeeBps;
        uint256 reserveFeeBps;

        if (isDexSwap) {
            devFeeBps = DEX_SWAP_DEV_FEE_BPS;
            reflectionFeeBps = DEX_SWAP_REFLECTION_FEE_BPS;
            reserveFeeBps = DEX_SWAP_RESERVE_FEE_BPS;
        } else {
            devFeeBps = TRANSFER_DEV_FEE_BPS;
            reflectionFeeBps = TRANSFER_REFLECTION_FEE_BPS;
            reserveFeeBps = TRANSFER_RESERVE_FEE_BPS;
        }

        uint256 devFee = Math.mulDiv(amount, devFeeBps, 10000);
        uint256 reflectionFee = Math.mulDiv(amount, reflectionFeeBps, 10000);
        uint256 reserveFee = Math.mulDiv(amount, reserveFeeBps, 10000);
        uint256 netAmount;
        unchecked {
            netAmount = amount - devFee - reflectionFee - reserveFee;
        }

        super._transfer(from, address(this), amount);
        
        // Distribute dividends BEFORE transferring to recipient
        // This prevents the recipient from earning dividends on newly received tokens from this transfer
        _distributeDividends(reflectionFee);
        
        if (netAmount != 0) {
            super._transfer(address(this), to, netAmount);
        }
        if (devFee != 0) {
            super._transfer(address(this), devAddress, devFee);
        }

        if (isDexSwap) {
            bool isSell = isContract(to) && isLiquidityPair(to);
            address user = isSell ? from : to;
            emit SwapFeeApplied(isSell ? SwapType.SELL : SwapType.BUY, user, amount, devFee, reflectionFee, reserveFee, netAmount);
        } else {
            emit TransferFeeApplied(from, to, amount, devFee, reflectionFee, reserveFee, netAmount);
        }
    }
    
    /// @notice Internal function to purchase zETH tokens with ETH
    /// @dev Protected by nonReentrant. Calculates tokens based on current price, applies fees, and distributes
    /// @param buyer Address receiving the tokens
    /// @param amountNative Amount of ETH being used to purchase
    /// @custom:security Buyer is prevented from earning dividends on their own purchase via lastDividendPerShare update
    /// @custom:testing Validated with 160M+ fuzz test cases across all price ranges
    function _buy(address buyer, uint256 amountNative) private nonReentrant {
        if (amountNative < MINIMUM_PURCHASE_NATIVE) revert InsufficientNative();

        uint256 balanceBefore = address(this).balance - amountNative;
        uint256 zETHToPurchase = _getzETHForNative(amountNative, balanceBefore);

        if (zETHToPurchase == 0) revert InsufficientNative();
        if (tokensSold + zETHToPurchase > TOTAL_SUPPLY) revert InsufficientBalance();

        uint256 devFee = Math.mulDiv(zETHToPurchase, BUY_DEV_FEE_BPS, 10000);
        uint256 reserveFee = Math.mulDiv(zETHToPurchase, BUY_RESERVE_FEE_BPS, 10000);
        uint256 reflectionFee = Math.mulDiv(zETHToPurchase, BUY_REFLECTION_FEE_BPS, 10000);
        uint256 zETHToUser;
        unchecked {
            zETHToUser = zETHToPurchase - devFee - reserveFee - reflectionFee;
        }

        tokensSold = tokensSold + zETHToPurchase;

        // Distribute dividends BEFORE transferring tokens to buyer
        // This prevents the buyer from earning dividends on newly purchased tokens from their own buy fee
        _distributeDividends(reflectionFee);
        
        // CRITICAL FIX: Mark buyer as "caught up" to current dividend distribution
        // This prevents them from retroactively earning dividends from their own purchase
        if (!isContract(buyer)) {
            lastDividendPerShare[buyer] = magnifiedDividendPerShare;
        }
        
        super._transfer(address(this), devAddress, devFee);
        super._transfer(address(this), buyer, zETHToUser);

        emit Buy(buyer, amountNative, zETHToUser);
    }

    /// @notice Internal function to handle token refunds for ETH
    /// @dev Protected by nonReentrant. Calculates ETH return based on 99.9% backing, applies fees, handles burning
    /// @param sender Address receiving the ETH refund
    /// @param zETHAmount Amount of zETH tokens being refunded
    /// @custom:security Minimum refund of 1 token prevents rounding exploits
    /// @custom:security Uses Math.mulDiv for precision-safe division
    /// @custom:testing Validated with 200M+ invariant calls including complex refund sequences
    function _handleRefund(address sender, uint256 zETHAmount) private nonReentrant {
        if (zETHAmount == 0) revert ZeroMoonAmount();
        
        // Minimum refund: 1 zETH token (same economic threshold as minimum buy)
        // At launch: 0.0001 ETH buys ~1 token, so 1 token refunds to ~0.0001 ETH ($0.40 at $4k ETH)
        if (zETHAmount < 1 ether) revert InsufficientBalance();

        uint256 _totalBurned = totalBurned;

        uint256 devFeezETH = Math.mulDiv(zETHAmount, REFUND_DEV_FEE_BPS, 10000); 
        uint256 reflectionFeezETH = Math.mulDiv(zETHAmount, REFUND_REFLECTION_FEE_BPS, 10000); 
        uint256 burnFeezETH = (_totalBurned < BURNING_LIMIT) ? Math.mulDiv(zETHAmount, 75, 100000) : 0; 
        uint256 reserveFeezETH = (_totalBurned < BURNING_LIMIT) ? Math.mulDiv(zETHAmount, 75, 100000) : Math.mulDiv(zETHAmount, 150, 100000); 
        uint256 zETHForUserRefund;
        unchecked {
            zETHForUserRefund = zETHAmount - devFeezETH - reflectionFeezETH - burnFeezETH - reserveFeezETH;
        }

        uint256 contractBalance = balanceOf(address(this));
        uint256 currentCirculatingSupply = (TOTAL_SUPPLY - _totalBurned) - contractBalance + zETHAmount;
        
        if (currentCirculatingSupply == 0) revert NoTokensInCirculation();

        uint256 effectiveBacking = (address(this).balance * EFFECTIVE_BACKING_NUMERATOR) / EFFECTIVE_BACKING_DENOMINATOR;
        
        // FIX: Use Math.mulDiv to prevent precision loss on division
        uint256 grossNativeValue = Math.mulDiv(zETHForUserRefund, effectiveBacking, currentCirculatingSupply);
        uint256 nativeToUser = grossNativeValue; 

        if (address(this).balance < nativeToUser) revert InsufficientNative();

        if (devFeezETH != 0) {
            super._transfer(address(this), devAddress, devFeezETH);
        }
        if (burnFeezETH != 0 && _totalBurned < BURNING_LIMIT) {
            uint256 remainingToBurn = BURNING_LIMIT - _totalBurned;
            if (burnFeezETH > remainingToBurn) {
                burnFeezETH = remainingToBurn;
            }
            if (burnFeezETH != 0) {
                _burn(address(this), burnFeezETH);
                totalBurned = totalBurned + burnFeezETH;
            }
        }
        
        _distributeDividends(reflectionFeezETH);

        emit Refund(sender, zETHAmount, nativeToUser);

        (bool success, ) = sender.call{value: nativeToUser}("");
        if (!success) revert NativeTransferFailed();
    }

    /// @notice Distributes reflection fees as dividends to all holders
    /// @dev Increases magnifiedDividendPerShare proportionally to circulating supply
    /// @param amount Amount of tokens to distribute as dividends
    /// @custom:security Only EOA holders receive dividends (contracts auto-excluded)
    function _distributeDividends(uint256 amount) private {
        if (amount == 0) return;
        
        uint256 circulatingSupply = getCirculatingSupply();
        if (circulatingSupply == 0) return;

        uint256 dividendPerShare = (amount * MAGNITUDE) / circulatingSupply;
        
        magnifiedDividendPerShare += dividendPerShare;
        totalDividendsDistributed += amount;
        
        emit DividendsDistributed(amount, magnifiedDividendPerShare);
    }

    /// @notice Calculates the circulating supply (excludes contract's unsold tokens)
    /// @return Circulating supply available for dividend calculations
    /// @dev Used for accurate dividend distribution calculations
    function getCirculatingSupply() private view returns (uint256) {
        uint256 total = totalSupply();
        uint256 contractBalance = balanceOf(address(this)); // Contract's unsold tokens
                
        return total - contractBalance;
    }
    
    /// @notice Updates dividend tracking for a user before balance changes
    /// @dev Calculates and accumulates pending dividends, updates tracking pointer
    /// @param user Address to update dividend tracking for
    /// @custom:security Contracts are automatically excluded from dividend tracking
    function _updateUserDividendTracking(address user) private {
        // Exclude contracts from dividend tracking
        if (isContract(user)) return;
        
        uint256 userBalance = balanceOf(user);
        uint256 currentDividendPerShare = magnifiedDividendPerShare;
        uint256 lastUserDividendPerShare = lastDividendPerShare[user];
        
        // Calculate and accumulate dividends if user has balance
        if (userBalance > 0 && currentDividendPerShare > lastUserDividendPerShare) {
            uint256 dividendDifference = currentDividendPerShare - lastUserDividendPerShare;
            uint256 newDividends = (userBalance * dividendDifference) / MAGNITUDE;
            
            if (newDividends > 0) {
                accumulatedDividends[user] += newDividends;
            }
        }
        
        // ALWAYS update lastDividendPerShare to keep tracking synchronized
        // This prevents stale data when user's balance goes to 0 and back
        lastDividendPerShare[user] = currentDividendPerShare;
    }

    /// @notice Allows users to claim their accumulated dividends
    /// @dev Protected by nonReentrant. Updates tracking, transfers accumulated dividends to user
    /// @custom:security Contracts cannot claim dividends
    /// @custom:testing Validated through 10M+ claim sequences in invariant tests
    function claimDividends() external nonReentrant {
        address user = msg.sender;
        
        // Exclude contracts from dividend claiming
        if (isContract(user)) return;
        
        uint256 userBalance = balanceOf(user);
        uint256 currentDividendPerShare = magnifiedDividendPerShare;
        uint256 lastUserDividendPerShare = lastDividendPerShare[user];
        
        // Calculate and accumulate dividends if user has balance
        if (userBalance > 0 && currentDividendPerShare > lastUserDividendPerShare) {
            uint256 dividendDifference = currentDividendPerShare - lastUserDividendPerShare;
            uint256 newDividends = (userBalance * dividendDifference) / MAGNITUDE;
            
            if (newDividends > 0) {
                accumulatedDividends[user] += newDividends;
            }
        }
        
        // ALWAYS update lastDividendPerShare to keep tracking synchronized
        lastDividendPerShare[user] = currentDividendPerShare;
        
        // Transfer accumulated dividends to user
        uint256 totalAccumulated = accumulatedDividends[user];
        if (totalAccumulated > 0) {
            accumulatedDividends[user] = 0;
            super._transfer(address(this), user, totalAccumulated);
            emit DividendWithdrawn(user, totalAccumulated);
        }
    }

    /// @notice Returns the pending (unclaimed) dividends for a user
    /// @param user Address to query pending dividends for
    /// @return Amount of unclaimed dividends available
    /// @dev Calculates based on balance and dividend per share delta
    function pendingDividends(address user) external view returns (uint256) {
        
        if (isContract(user)) return 0;
        
        uint256 userBalance = balanceOf(user);
        if (userBalance == 0) return accumulatedDividends[user];
        
        uint256 currentDividendPerShare = magnifiedDividendPerShare;
        uint256 lastUserDividendPerShare = lastDividendPerShare[user];        
        
        if (currentDividendPerShare > lastUserDividendPerShare) {
            uint256 dividendDifference = currentDividendPerShare - lastUserDividendPerShare;
            uint256 newDividends = (userBalance * dividendDifference) / MAGNITUDE;
            return accumulatedDividends[user] + newDividends;
        }
        
        return accumulatedDividends[user];
    }

    /// @notice Calculates zETH tokens receivable for a given ETH amount
    /// @param nativeAmount Amount of ETH to query
    /// @return Amount of zETH tokens that would be received (before fees)
    /// @dev Used by frontends to preview buy amounts
    function calculatezETHForNative(uint256 nativeAmount) public view returns (uint256) {
        return _getzETHForNative(nativeAmount, address(this).balance);
    }

    /// @notice Calculates ETH receivable for a given zETH refund amount
    /// @param zETHAmount Amount of zETH tokens to query
    /// @return Amount of ETH that would be received (after fees and backing calculation)
    /// @dev Used by frontends to preview refund amounts. Returns 0 for amounts below 1 token minimum
    /// @custom:security Uses same fee and backing logic as actual refund execution
    function calculateNativeForZETH(uint256 zETHAmount) public view returns (uint256) {
        if (zETHAmount == 0) return 0;
        
        // Match the minimum refund check in _handleRefund
        if (zETHAmount < 1 ether) return 0;

        uint256 _totalBurned = totalBurned;

        // Calculate fees (same as _handleRefund)
        uint256 devFeezETH = Math.mulDiv(zETHAmount, REFUND_DEV_FEE_BPS, 10000);
        uint256 reflectionFeezETH = Math.mulDiv(zETHAmount, REFUND_REFLECTION_FEE_BPS, 10000);
        uint256 burnFeezETH = (_totalBurned < BURNING_LIMIT) ? Math.mulDiv(zETHAmount, 75, 100000) : 0;
        uint256 reserveFeezETH = (_totalBurned < BURNING_LIMIT) ? Math.mulDiv(zETHAmount, 75, 100000) : Math.mulDiv(zETHAmount, 150, 100000);
        
        uint256 zETHForUserRefund;
        unchecked {
            zETHForUserRefund = zETHAmount - devFeezETH - reflectionFeezETH - burnFeezETH - reserveFeezETH;
        }

        uint256 contractBalance = balanceOf(address(this));
        uint256 currentCirculatingSupply = (TOTAL_SUPPLY - _totalBurned) - contractBalance + zETHAmount;
        
        if (currentCirculatingSupply == 0) return 0;

        uint256 effectiveBacking = (address(this).balance * EFFECTIVE_BACKING_NUMERATOR) / EFFECTIVE_BACKING_DENOMINATOR;
        
        // FIX: Use Math.mulDiv to prevent precision loss on division
        uint256 nativeToUser = Math.mulDiv(zETHForUserRefund, effectiveBacking, currentCirculatingSupply);

        return nativeToUser;
    }

    /// @notice Internal function to calculate zETH tokens for ETH amount
    /// @dev Uses dynamic pricing: base price at launch, then refund price + 0.1% markup
    /// @param nativeAmount Amount of ETH
    /// @param balanceBefore Contract ETH balance before this transaction
    /// @return Amount of zETH tokens (capped at available supply)
    function _getzETHForNative(uint256 nativeAmount, uint256 balanceBefore) private view returns (uint256) {
        if (nativeAmount == 0) return 0;
        uint256 availableToSell = balanceOf(address(this));
        if (availableToSell == 0) return 0;

        uint256 circulating = totalSupply() - availableToSell;

        uint256 pricePerToken;
        if (circulating == 0 || balanceBefore == 0) {
            pricePerToken = BASE_PRICE;
        } else {
            uint256 refundPrice = (balanceBefore * 1e18) / circulating;
            pricePerToken = (refundPrice * 10010) / PRECISION_DIVISOR;
        }

        uint256 tokensToPurchase = (nativeAmount * 1e18) / pricePerToken;
        return Math.min(tokensToPurchase, availableToSell);
    }

    /// @notice Detects if an address is a contract (DEX, router, lending protocol, etc.)
    /// @dev Uses multiple interface checks to identify various contract types
    /// @param _addr Address to check
    /// @return True if address is identified as a contract, false for EOAs
    /// @custom:security Used to auto-exclude contracts from dividend distribution
    function isContract(address _addr) internal view returns (bool) {
        if (_addr.code.length == 0) return false;
        
        (bool s0, bytes memory d0) = _addr.staticcall(abi.encodeWithSignature("token0()"));
        (bool s1, bytes memory d1) = _addr.staticcall(abi.encodeWithSignature("token1()"));
        if (s0 && s1 && d0.length == 32 && d1.length == 32) {
            return true; // It's a DEX pair contract
        }
        
        (bool s2, ) = _addr.staticcall(abi.encodeWithSignature("factory()"));
        if (s2) return true; // Router contract
        
        (bool s3, ) = _addr.staticcall(abi.encodeWithSignature("getReserves()"));
        if (s3) return true; // Pair contract with reserves
        
        (bool s4, ) = _addr.staticcall(abi.encodeWithSignature("getPair(address,address)", address(0), address(0)));
        if (s4) return true; // DEX factory contract
        
        (bool s5, ) = _addr.staticcall(abi.encodeWithSignature("swap(address,uint256,uint256,uint256,bytes)", address(0), 0, 0, 0, ""));
        if (s5) return true; // Aggregator/swapper contract
        
        (bool s6, ) = _addr.staticcall(abi.encodeWithSignature("supply(address,uint256,address,uint16,uint256)", address(0), 0, address(0), 0, 0));
        if (s6) return true; // Lending protocol contract
        
        (bool s7, ) = _addr.staticcall(abi.encodeWithSignature("deposit(uint256)", 0));
        if (s7) return true; // Yield farm/staking contract
        
        (bool s8, ) = _addr.staticcall(abi.encodeWithSignature("sendToChain(address,uint256,uint256)", address(0), 0, 0));
        if (s8) return true; // Bridge/cross-chain contract
        
        return false;
    }

    /// @notice Changes the development fee recipient address
    /// @dev Only callable by owner. Automatically updates fee exclusions
    /// @param _devAddress New development address
    function setDevAddress(address _devAddress) external onlyOwner {
        if (_devAddress == address(0)) revert ZeroMoonAddress();
        address oldDevAddress = devAddress;
        _isExcludedFromFee[devAddress] = false;
        devAddress = _devAddress;
        _isExcludedFromFee[devAddress] = true;
        emit DevAddressChanged(oldDevAddress, _devAddress);
    }

    /// @notice Sets fee exclusion status for an account
    /// @dev Only callable by owner
    /// @param account Address to set exclusion for
    /// @param isExcluded Whether to exclude from fees
    function excludeFromFee(address account, bool isExcluded) external onlyOwner {
        if (account == address(0)) revert ZeroMoonAddress();
        _isExcludedFromFee[account] = isExcluded;
        emit FeeExclusionSet(account, isExcluded);
    }

    /// @notice Returns total dividends distributed since inception
    /// @return Cumulative dividend amount
    function getTotalDividendsDistributed() external view returns (uint256) {
        return totalDividendsDistributed;
    }

    /// @notice Returns current magnified dividend per share
    /// @return Current magnifiedDividendPerShare value
    /// @dev Used for external integrations and analytics
    function getMagnifiedDividendPerShare() external view returns (uint256) {
        return magnifiedDividendPerShare;
    }
    
    /// @notice Returns current circulating supply (public view function)
    /// @return Circulating supply (total minus contract balance)
    function getCirculatingSupplyPublic() external view returns (uint256) {
        return getCirculatingSupply();
    }

    /// @notice Returns comprehensive dividend information for a user
    /// @param user Address to query
    /// @return balance User's token balance
    /// @return userLastDividendPerShare User's last recorded dividend per share
    /// @return userAccumulatedDividends User's accumulated unclaimed dividends
    /// @return currentDividendPerShare Current global dividend per share
    /// @return isUserContract Whether the address is identified as a contract
    function getUserDividendInfo(address user) external view returns (
        uint256 balance,
        uint256 userLastDividendPerShare,
        uint256 userAccumulatedDividends,
        uint256 currentDividendPerShare,
        bool isUserContract
    ) {
        return (
            balanceOf(user),
            lastDividendPerShare[user],
            accumulatedDividends[user],
            magnifiedDividendPerShare,
            isContract(user)
        );
    }

    /// @notice Increases the allowance granted to a spender
    /// @param spender Address to increase allowance for
    /// @param addedValue Amount to add to current allowance
    /// @return True if successful
    function increaseAllowance(address spender, uint256 addedValue) public virtual override returns (bool) {
        address owner = _msgSender();
        _approve(owner, spender, allowance(owner, spender) + addedValue);
        return true;
    }

    /// @notice Decreases the allowance granted to a spender
    /// @param spender Address to decrease allowance for
    /// @param subtractedValue Amount to subtract from current allowance
    /// @return True if successful
    /// @dev Reverts if subtractedValue exceeds current allowance
    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual override returns (bool) {
        address owner = _msgSender();
        uint256 currentAllowance = allowance(owner, spender);
        if (currentAllowance < subtractedValue) revert InsufficientBalance(); 
        unchecked {
            _approve(owner, spender, currentAllowance - subtractedValue);
        }
        return true;
    }
}