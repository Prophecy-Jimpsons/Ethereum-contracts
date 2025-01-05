// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts@4.9.0/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts@4.9.0/access/Ownable.sol";
import "@openzeppelin/contracts@4.9.0/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts@4.9.0/utils/math/SafeMath.sol";

contract TokenPresale is Ownable, ReentrancyGuard {
    using SafeMath for uint256;

    IERC20 public token;
    address payable public fundWallet;
    
    uint256 public presaleRate;      // How many tokens per 1 ETH
    uint256 public softCap;          // Minimum goal in ETH
    uint256 public hardCap;          // Maximum goal in ETH
    uint256 public minPurchase;      // Minimum purchase per address in ETH
    uint256 public maxPurchase;      // Maximum purchase per address in ETH
    
    uint256 public presaleStart;     // Timestamp when presale starts
    uint256 public presaleEnd;       // Timestamp when presale ends
    
    uint256 public totalRaised;      // Total ETH raised
    
    bool public presaleFinalized;
    bool public refundsEnabled;
    
    mapping(address => uint256) public contributions;
    mapping(address => bool) public refundClaimed;
    
    event TokensPurchased(address indexed purchaser, uint256 ethAmount, uint256 tokenAmount);
    event PresaleFinalized(uint256 totalRaised);
    event RefundsClaimed(address indexed refundee, uint256 ethAmount);
    
    constructor(
        address payable _fundWallet,
        uint256 _presaleRate,
        uint256 _softCap,
        uint256 _hardCap,
        uint256 _minPurchase,
        uint256 _maxPurchase,
        uint256 _presaleStart,
        uint256 _presaleDuration
    ) {
        require(_fundWallet != address(0), "Invalid fund wallet");
        require(_presaleRate > 0, "Rate must be greater than 0");
        require(_softCap > 0 && _hardCap > _softCap, "Invalid caps");
        require(_maxPurchase >= _minPurchase, "Invalid purchase limits");
        
        // Set token address directly to your deployed token
        token = IERC20(0xF6e734e8206756aDD13daA30f2cdE3dDc8E8345f);
        fundWallet = _fundWallet;
        presaleRate = _presaleRate;
        softCap = _softCap;
        hardCap = _hardCap;
        minPurchase = _minPurchase;
        maxPurchase = _maxPurchase;
        presaleStart = _presaleStart;
        presaleEnd = _presaleStart + _presaleDuration;
    }
    
    function participate() external payable nonReentrant {
        require(block.timestamp >= presaleStart, "Presale not started");
        require(block.timestamp <= presaleEnd, "Presale ended");
        require(!presaleFinalized, "Presale finalized");
        require(msg.value >= minPurchase, "Below minimum contribution");
        require(msg.value.add(contributions[msg.sender]) <= maxPurchase, "Exceeds maximum contribution");
        require(totalRaised.add(msg.value) <= hardCap, "Hard cap reached");
        
        uint256 tokenAmount = calculateTokenAmount(msg.value);
        require(token.balanceOf(address(this)) >= tokenAmount, "Insufficient tokens in contract");
        
        contributions[msg.sender] = contributions[msg.sender].add(msg.value);
        totalRaised = totalRaised.add(msg.value);
        
        emit TokensPurchased(msg.sender, msg.value, tokenAmount);
    }
    
    function calculateTokenAmount(uint256 ethAmount) public view returns (uint256) {
        return ethAmount.mul(presaleRate).mul(10 ** 18); // Adjusted for 18 decimals
    }
    
    function finalize() external onlyOwner {
        require(block.timestamp > presaleEnd || totalRaised >= hardCap, "Cannot finalize yet");
        require(!presaleFinalized, "Already finalized");
        
        presaleFinalized = true;
        
        if (totalRaised >= softCap) {
            fundWallet.transfer(address(this).balance);
        } else {
            refundsEnabled = true;
        }
        
        emit PresaleFinalized(totalRaised);
    }
    
    function claimTokens() external nonReentrant {
        require(presaleFinalized, "Presale not finalized");
        require(!refundsEnabled, "Presale failed");
        require(contributions[msg.sender] > 0, "No contribution found");
        
        uint256 tokenAmount = calculateTokenAmount(contributions[msg.sender]);
        contributions[msg.sender] = 0;
        
        require(token.transfer(msg.sender, tokenAmount), "Token transfer failed");
    }
    
    function withdrawUnsoldTokens() external onlyOwner {
        require(presaleFinalized, "Presale not finalized");
        require(!refundsEnabled, "Presale failed");
        
        uint256 unsoldTokens = token.balanceOf(address(this));
        require(token.transfer(owner(), unsoldTokens), "Token transfer failed");
    }

    // Emergency function to recover accidentally sent ERC20 tokens
    function recoverERC20(address tokenAddress) external onlyOwner {
        require(tokenAddress != address(token), "Cannot recover presale token");
        
        IERC20 tokenToRecover = IERC20(tokenAddress);
        uint256 balance = tokenToRecover.balanceOf(address(this));
        require(tokenToRecover.transfer(owner(), balance), "Token recovery failed");
    }
}