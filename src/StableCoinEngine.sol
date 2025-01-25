// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "./stablecoin.sol";

error Engine__InvalidAmount();
error Engine__TransferFailed();
error Engine__UnsafePositionRatio();
error Engine__MintingFailed();
error Engine__PositionSafe();
error Engine__NotLiquidatable();

contract StableCoinEngine {
    uint256 private constant COLLATERAL_RATIO = 150; // 150% collateralization required (one and a half times the amount of stablecoin minted)
    uint256 private constant LIQUIDATOR_REWARD = 10; // 10% reward for liquidators
    uint256 private constant SAFE_POSITION_THRESHOLD = 1e18; // 1 * 1e18 (pegged to the price of ETH)

    StableCoin private immutable i_stableCoin;

    // ETH/USD price with 18 decimals
    uint256 public s_pricePoint;

    mapping(address => uint256) public s_userCollateral; // User's collateral balance
    mapping(address => uint256) public s_userMinted; // User's minted stablecoin balance

    event CollateralAdded(address indexed user, uint256 indexed amount);
    event CollateralWithdrawn(address indexed from, address indexed to, uint256 indexed amount);

    constructor(address stableCoinAddress) {
        i_stableCoin = StableCoin(stableCoinAddress);
        s_pricePoint = 3333e18; // Starting ETH price of $3333
    }

    // Allows users to add collateral and mint stablecoins in a single transaction
    function addCollateralAndMint(uint256 mintAmount) external payable {
        addCollateral(); // Add collateral sent with the transaction
        mintStableCoin(mintAmount); // Mint the specified amount of stablecoins
    }

    // Allows users to add collateral to their account
    function addCollateral() public payable {
        if (msg.value == 0) {
            revert Engine__InvalidAmount(); // Revert if no collateral is sent
        }
        s_userCollateral[msg.sender] += msg.value; // Update user's collateral balance
        emit CollateralAdded(msg.sender, msg.value); // Emit event for collateral addition
    }

    // Allows users to mint stablecoins based on their collateral
    function mintStableCoin(uint256 mintAmount) public {
        if (mintAmount == 0) {
            revert Engine__InvalidAmount(); // Revert if mint amount is zero
        }
        s_userMinted[msg.sender] += mintAmount; // Update user's minted stablecoin balance
        _validatePosition(msg.sender); // Validate user's position before minting
        bool success = i_stableCoin.mintTo(msg.sender, mintAmount); // Mint stablecoins to user
        if (!success) {
            revert Engine__MintingFailed(); // Revert if minting fails
        }
    }

    // Retrieves the user's position, including minted amount and collateral value
    function _getUserPosition(address user) private view returns (uint256 mintedAmount, uint256 collateralValue) {
        mintedAmount = s_userMinted[user]; // Get user's minted amount
        collateralValue = calculateCollateralValue(user); // Calculate user's collateral value
    }

    // Calculates the total collateral value for a user based on their collateral balance and price point
    function calculateCollateralValue(address user) public view returns (uint256) {
        uint256 collateralAmount = s_userCollateral[user]; // Get user's collateral amount
        return (collateralAmount * s_pricePoint) / 1e18; // Calculate collateral value in terms of ETH price
    }

    // Calculates the position ratio for a user to ensure they are within safe limits
    function _calculatePositionRatio(address user) private view returns (uint256) {
        (uint256 mintedAmount, uint256 collateralValue) = _getUserPosition(user); // Get user's position
        if (mintedAmount == 0) return type(uint256).max; // Return max if no stablecoins are minted
        uint256 adjustedCollateral = (collateralValue * COLLATERAL_RATIO) / 100; // Adjust collateral based on ratio
        return (adjustedCollateral * 1e18) / mintedAmount; // Calculate position ratio
    }

    // Validates the user's position to ensure it meets safety requirements
    function _validatePosition(address user) internal view {
        uint256 positionRatio = _calculatePositionRatio(user); // Calculate user's position ratio
        if (positionRatio < SAFE_POSITION_THRESHOLD) {
            revert Engine__UnsafePositionRatio(); // Revert if position is unsafe
        }
    }

    // Simulates an oracle function to update the ETH price; in production, use a real price feed
    function updatePrice(uint256 newPrice) external {
        s_pricePoint = newPrice; // Update the stored price point
    }
}