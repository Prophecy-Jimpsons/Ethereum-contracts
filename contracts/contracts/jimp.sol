// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Prophecy_Jimpsons is ERC20, Ownable(msg.sender) {
    uint256 public constant MAX_SUPPLY = 500_000_000 * 10**18;
    uint256 public constant MAX_TRANSFER_AMOUNT = 10_000_000 * 10**18;
    uint256 public constant COOLDOWN_PERIOD = 1 days;

    mapping(address => bool) public isWhitelisted;
    mapping(address => uint256) public lastTransferTimestamp;
    mapping(address => uint256) public transferredAmount;

    event AddressWhitelisted(address indexed account, bool status);

    constructor() ERC20("Prophecy Jimpsons", "Zimp") {
        _mint(msg.sender, MAX_SUPPLY);
        isWhitelisted[msg.sender] = true; // Owner is whitelisted by default
    }

    modifier checkTransferRestrictions(address from, uint256 amount) {
        if (!isWhitelisted[from] && from != owner()) {
            require(amount <= MAX_TRANSFER_AMOUNT, "Transfer amount exceeds limit");
            
            uint256 newTotal = transferredAmount[from] + amount;
            if (newTotal >= MAX_TRANSFER_AMOUNT) {
                require(
                    block.timestamp >= lastTransferTimestamp[from] + COOLDOWN_PERIOD,
                    "Cooldown period active"
                );
                transferredAmount[from] = amount;
            } else {
                transferredAmount[from] = newTotal;
            }
            
            lastTransferTimestamp[from] = block.timestamp;
        }
        _;
    }

    function setWhitelistStatus(address account, bool status) external onlyOwner {
        isWhitelisted[account] = status;
        emit AddressWhitelisted(account, status);
    }

    function transfer(address to, uint256 amount) 
        public 
        override 
        checkTransferRestrictions(msg.sender, amount)
        returns (bool) 
    {
        require(to != address(0), "Invalid recipient");
        return super.transfer(to, amount);
    }

    function transferFrom(address from, address to, uint256 amount)
        public
        override
        checkTransferRestrictions(from, amount)
        returns (bool)
    {
        require(to != address(0), "Invalid recipient");
        return super.transferFrom(from, to, amount);
    }

    // View function to check remaining cooldown time
    function getRemainingCooldown(address account) public view returns (uint256) {
        if (isWhitelisted[account] || account == owner()) {
            return 0;
        }
        uint256 timePassed = block.timestamp - lastTransferTimestamp[account];
        if (timePassed >= COOLDOWN_PERIOD) {
            return 0;
        }
        return COOLDOWN_PERIOD - timePassed;
    }
}
