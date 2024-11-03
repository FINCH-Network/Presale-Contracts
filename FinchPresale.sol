// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Importing ERC20 and ReentrancyGuard from OpenZeppelin
import "./IERC20.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/security/ReentrancyGuard.sol";

// FinchPresale contract
contract FinchPresale is ReentrancyGuard {
    address public admin;
    IERC20 public finchToken;
    bool public isPresaleActive;
    bool public presaleFinalized;
    
    // Private constants for optimization
    uint256 private constant FINCH_PER_MO = 10; // 1 MO buys 10 FINCH
    uint256 private constant PRESALE_ALLOCATION = 50_000_000 * 10 ** 18; // 50 million FINCH for presale
    uint256 private constant MAX_PURCHASE_PER_WALLET = 1_000_000 * 10 ** 18; // 1 million FINCH max per wallet

    uint256 public totalTokensSold;

    mapping(address => uint256) public purchasedAmount;

    event TokensPurchased(address indexed buyer, uint256 moAmount, uint256 finchAmount);
    event PresaleFinalized();
    event FundsWithdrawn(address indexed admin, uint256 amount);

    constructor(address _finchToken) {
        admin = msg.sender;
        finchToken = IERC20(_finchToken);
        isPresaleActive = true;
        presaleFinalized = false;
    }

    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin");
        _;
    }

    modifier presaleActive() {
        require(isPresaleActive && !presaleFinalized, "Presale inactive");
        _;
    }

    function buyTokens() external payable presaleActive nonReentrant {
        require(msg.value > 0 ether, "Minimum 1 MO");

        uint256 finchAmount = msg.value * FINCH_PER_MO;

        // Check if the purchase exceeds the wallet limit
        require(purchasedAmount[msg.sender] + finchAmount < MAX_PURCHASE_PER_WALLET, "Over wallet limit");

        // Check if the total tokens sold exceeds the presale allocation
        require(totalTokensSold + finchAmount < PRESALE_ALLOCATION, "Exceeds allocation");

        // Update state before transfer to prevent reentrancy
        purchasedAmount[msg.sender] = purchasedAmount[msg.sender] + finchAmount;
        totalTokensSold = totalTokensSold + finchAmount;

        // Transfer FINCH tokens to buyer
        require(finchToken.transfer(msg.sender, finchAmount), "Transfer failed");

        emit TokensPurchased(msg.sender, msg.value, finchAmount);
    }

    function finalizePresale() external onlyAdmin {
        require(!presaleFinalized, "Already finalized");

        isPresaleActive = false;
        presaleFinalized = true;

        emit PresaleFinalized();
    }

    function withdrawFunds() external onlyAdmin nonReentrant {
        require(presaleFinalized, "Finalize first");

        uint256 balance = address(this).balance;
        require(balance != 0, "No funds");

        emit FundsWithdrawn(admin, balance);

        (bool success, ) = payable(admin).call{value: balance}("");
        require(success, "Transfer failed");
    }

    function emergencyWithdrawTokens() external onlyAdmin nonReentrant {
        require(!isPresaleActive, "Active presale");

        uint256 balance = finchToken.balanceOf(address(this));
        require(balance != 0, "No FINCH tokens");

        require(finchToken.transfer(admin, balance), "Transfer failed");
    }

    function togglePresale() external onlyAdmin {
        isPresaleActive = !isPresaleActive;
    }
}
