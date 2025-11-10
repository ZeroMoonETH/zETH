// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "forge-std/Script.sol";
import "../ZEROMOON/src/lib/ZeroMoon.sol";

/**
 * @title Deploy ZeroMoon zETH
 * @notice Deployment script for ZeroMoon token contract
 * @dev Usage:
 *      forge script script/Deploy.s.sol --rpc-url $RPC_URL --broadcast --verify
 */
contract DeployZeroMoon is Script {
    
    // Environment variables (set in .env)
    // PRIVATE_KEY=0x...
    // DEV_ADDRESS=0x...
    // INITIAL_ETH=0 (optional, in wei)
    
    function run() external {
        // Load configuration from environment
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address devAddress = vm.envAddress("DEV_ADDRESS");
        uint256 initialETH = vm.envOr("INITIAL_ETH", uint256(0));
        
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("=== ZeroMoon zETH Deployment ===");
        console.log("");
        console.log("Network:");
        console.log("  Chain ID:", block.chainid);
        console.log("  Block Number:", block.number);
        console.log("");
        console.log("Configuration:");
        console.log("  Deployer:", deployer);
        console.log("  Dev Address:", devAddress);
        console.log("  Initial ETH:", initialETH);
        console.log("");
        
        // Verify deployer has sufficient balance
        uint256 deployerBalance = deployer.balance;
        console.log("Deployer Balance:", deployerBalance);
        require(deployerBalance >= initialETH, "Insufficient deployer balance");
        
        console.log("");
        console.log("Deploying ZeroMoon contract...");
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy the contract
        ZeroMoon token = new ZeroMoon{value: initialETH}(deployer, devAddress);
        
        vm.stopBroadcast();
        
        console.log("");
        console.log("=== Deployment Successful ===");
        console.log("");
        console.log("Contract Address:", address(token));
        console.log("");
        console.log("Contract Configuration:");
        console.log("  Name:", token.name());
        console.log("  Symbol:", token.symbol());
        console.log("  Total Supply:", token.TOTAL_SUPPLY() / 1e18, "tokens");
        console.log("  Burning Limit:", token.BURNING_LIMIT() / 1e18, "tokens (20%)");
        console.log("  Minimum Buy:", token.MINIMUM_PURCHASE_NATIVE());
        console.log("  Tokens Sold:", token.tokensSold() / 1e18, "tokens");
        console.log("  Contract ETH Balance:", address(token).balance);
        console.log("");
        
        // Save deployment info to file
        string memory deploymentInfo = string.concat(
            "ZeroMoon zETH Deployment\n",
            "========================\n",
            "Chain ID: ", vm.toString(block.chainid), "\n",
            "Contract: ", vm.toString(address(token)), "\n",
            "Deployer: ", vm.toString(deployer), "\n",
            "Dev Address: ", vm.toString(devAddress), "\n",
            "Block: ", vm.toString(block.number), "\n"
        );
        
        vm.writeFile(
            string.concat("deployments/", vm.toString(block.chainid), ".txt"),
            deploymentInfo
        );
        
        console.log("Next Steps:");
        console.log("");
        console.log("1. Verify the contract on Etherscan:");
        console.log("   forge verify-contract \\");
        console.log("     --chain-id", block.chainid, "\\");
        console.log("     --constructor-args $(cast abi-encode \"constructor(address,address)\"", deployer, devAddress, ") \\");
        console.log("     ", address(token), "\\");
        console.log("     ZEROMOON/src/lib/ZeroMoon.sol:ZeroMoon");
        console.log("");
        console.log("2. Test the deployment:");
        console.log("   - Call token.buy() with ETH");
        console.log("   - Verify balances");
        console.log("   - Test refund mechanism");
        console.log("");
        console.log("3. After verification, consider renouncing ownership:");
        console.log("   cast send", address(token), "\"renounceOwnership()\" --rpc-url $RPC_URL --private-key $PRIVATE_KEY");
        console.log("");
        console.log("=== Deployment Complete ===");
    }
}

/**
 * @title Deploy ZeroMoon to Testnet
 * @notice Testnet deployment with additional testing features
 */
contract DeployTestnet is Script {
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("TESTNET_PRIVATE_KEY");
        address devAddress = vm.envAddress("DEV_ADDRESS");
        
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("=== ZeroMoon zETH TESTNET Deployment ===");
        console.log("Chain ID:", block.chainid);
        console.log("Deployer:", deployer);
        console.log("Dev Address:", devAddress);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy with some initial ETH for testing
        ZeroMoon token = new ZeroMoon{value: 0.1 ether}(deployer, devAddress);
        
        // Perform some initial operations for testing
        console.log("\nPerforming test operations...");
        
        // Buy some tokens
        token.buy{value: 0.01 ether}();
        console.log("Test buy executed");
        
        // Check balance
        uint256 balance = token.balanceOf(deployer);
        console.log("Deployer token balance:", balance / 1e18);
        
        vm.stopBroadcast();
        
        console.log("\n=== Testnet Deployment Complete ===");
        console.log("Contract:", address(token));
        console.log("\nTest the contract:");
        console.log("- Buy tokens: cast send", address(token), "\"buy()\" --value 0.01ether --rpc-url $TESTNET_RPC_URL --private-key $TESTNET_PRIVATE_KEY");
        console.log("- Check balance: cast call", address(token), "\"balanceOf(address)\" YOUR_ADDRESS --rpc-url $TESTNET_RPC_URL");
    }
}

/**
 * @title Verify ZeroMoon on Etherscan
 * @notice Verification script for already deployed contracts
 */
contract VerifyZeroMoon is Script {
    
    function run() external view {
        address contractAddress = vm.envAddress("CONTRACT_ADDRESS");
        address initialOwner = vm.envAddress("INITIAL_OWNER");
        address devAddress = vm.envAddress("DEV_ADDRESS");
        
        console.log("=== Etherscan Verification Command ===");
        console.log("");
        console.log("forge verify-contract \\");
        console.log("  --chain-id", block.chainid, "\\");
        console.log("  --constructor-args $(cast abi-encode \"constructor(address,address)\"", initialOwner, devAddress, ") \\");
        console.log("  ", contractAddress, "\\");
        console.log("  ZEROMOON/src/lib/ZeroMoon.sol:ZeroMoon \\");
        console.log("  --etherscan-api-key $ETHERSCAN_API_KEY");
        console.log("");
    }
}

