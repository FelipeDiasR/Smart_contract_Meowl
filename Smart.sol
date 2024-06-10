// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/* 
 * @title TokenSale - MeowlPad
 * @MeowlTeam A contract for conducting token sales and managing fundraising activities.
 */

contract TokenSale is Ownable {
    IERC20 public token;
    IERC20 public stablecoin;
    uint256 public tokenPrice; // token price in cents
    uint256 public vestingPeriod;
    uint256 public vestingInterval;
    uint256 public tgePercentage; // Percentual do TGE (de 0 a 100)
    uint256 public tgeStartTime;
    uint256 public totalTokensDeposited;
    bool public isTgeActivated; 
    bool public isContractActived;
    bool public isPromotionActived;
    
     /**
     * @dev Struct to store user data related to token purchases and claims.
     */

    struct User {
        uint256 totalInvested;   // defined inside buy token
        uint256 totalPurchased;  // defined inside buy token
        uint256 claimedAmount;   // defined inside claim function Need to be updated yet
        uint256 numberOfClaims;  // defined inside  buy token Need to be updated yet
        uint256 tokensPerClaim;  // defined inside buy token  Used
        uint256 tgeAmount;       // defined inside buy token Used
    }

     /**
     * @dev Struct to store fundraising data including the fundraising goal and the amount already capitated.
     */

    struct Fundraising {
        uint256 fundraisingGoal;
        uint256 alreadyCapitated;

    }
    
    Fundraising public fundraising;
    mapping(address => User) public users;
    mapping(address => bool) public waitlist;
    address[] public waitlistAddresses;
    


    event TokensDeposited(uint256 amount);
    event TokensPurchased(address buyer, uint256 amount);
    event tgeClaimed(address indexed user, uint256 amount);
    event TokensClaimed(address user, uint256 amount);
    event SubscribedToWaitList(address user);
    event TokensWithdrawn(address indexed owner, address indexed token, uint256 amount);

     /**
     * @dev Contract constructor to initialize parameters.
     * @param _tokenAddress The address of the token contract
     * @param _stablecoinAddress The address of the stablecoin contract
     * @param _vestingPeriod The vesting period for token claims
     * @param _vestingInterval The interval for token claims
     * @param _tgePercentage The percentage of TGE
     */

     constructor(
        address _tokenAddress, 
        address _stablecoinAddress,
        uint256 _vestingPeriod, 
        uint256 _vestingInterval, 
        uint256 _tgePercentage 
    ) Ownable(msg.sender) {
        token = IERC20(_tokenAddress);
        stablecoin = IERC20(_stablecoinAddress);
        vestingPeriod = _vestingPeriod;
        vestingInterval = _vestingInterval;
        tgePercentage = _tgePercentage;
        isTgeActivated = false;
        isContractActived = false;
        isPromotionActived = false;
    }

    /**
     * @dev Function to set the token price.
     * @param _price The price of the token in cents.
     */

    function setTokenPrice(uint256 _price) external onlyOwner {
        require(_price > 0, "Token price must be greater than zero");
        tokenPrice = _price;
    }

    /**
     * @dev Function to deposit tokens into the contract.
     * @param _amount The amount of tokens to deposit.
     */

    function depositTokens(uint256 _amount) external onlyOwner {                     
        require(token.transferFrom(msg.sender, address(this), _amount), "Token transfer failed");
        require(_amount > 0, "The amount need to be bigger than zero");
       
       totalTokensDeposited += _amount; // Update the total tokens deposited

        emit TokensDeposited(_amount);
    }

    /**
     * @dev Function to activate the TGE (Token Generation Event).
     * @param _isActive The activation status of the TGE.
     */

    function setTgeActivation(bool _isActive) external onlyOwner {
        require(isTgeActivated != _isActive, "TGE activation status is already set to the specified value");
        require(stablecoin.balanceOf(address(this)) > 0, "Contract stablecoin balance is insufficient");

        isTgeActivated = _isActive;
        tgeStartTime = block.timestamp;

    }

    /**
     * @dev Function to activate or deactivate the contract.
     * @param _isActive The activation status of the contract.
     */

    function setContractActivation(bool _isActive) external onlyOwner {
        require(isContractActived != _isActive, "New state must be different from current state");
        
        isContractActived = _isActive;
    }

    /**
     * @dev Function to activate or deactivate the promotion.
     * @param _isActive The activation status of the promotion.
     */
    function setPromotionActived(bool _isActive) external onlyOwner {
        require(isPromotionActived != _isActive, "New state must be different from current state");
        
        isPromotionActived = _isActive;
    }

    /**
     * @dev Function to purchase tokens.
     * @param _stablecoinAmount The amount of stablecoins to be converted into tokens.
     */
    function buyTokens(uint256 _stablecoinAmount) external {
        require(isPromotionActived || waitlist[msg.sender], "User is not in waitlist or promotion is not active");
        require(isContractActived, "contract need to be actived");
        require(tokenPrice > 0, "Token price not set");
       
        uint256 tokenAmount = _stablecoinAmount * (10 ** 18) / tokenPrice;  // Quantidade de tokens
        uint256 tgeCalculation = tokenAmount * tgePercentage / 100;
        uint256 claimCalculation = vestingPeriod / vestingInterval;
        uint256 tokenPerClaim = (tgePercentage > 0) 
        ? (tokenAmount - tgeCalculation) / claimCalculation 
        : tokenAmount / claimCalculation;

        require(stablecoin.transferFrom(msg.sender, address(this), _stablecoinAmount), "Stablecoin transfer failed");

        users[msg.sender].totalPurchased += tokenAmount;
        users[msg.sender].numberOfClaims += claimCalculation;
        users[msg.sender].totalInvested += _stablecoinAmount;
        users[msg.sender].tgeAmount += tgeCalculation;
        users[msg.sender].tokensPerClaim = tokenPerClaim;
        fundraising.alreadyCapitated += _stablecoinAmount;
        

        emit TokensPurchased(msg.sender, tokenAmount);
    }

     /**
     * @dev Function to claim tokens from TGE (Token Generation Event).
     */
    function claimTge() external {
        User storage userData = users[msg.sender];
        require(isTgeActivated, "Contract is not activated");
        require(userData.tgeAmount > 0, "no TGE amount");
        
        uint256 claimbleAmount = userData.tgeAmount;

        require(token.transfer(msg.sender, claimbleAmount), "token transfer failed");
        userData.tgeAmount -= claimbleAmount;
        userData.claimedAmount += claimbleAmount;

        emit tgeClaimed(msg.sender, claimbleAmount);
    }

    /**
     * @dev Function to claim tokens after TGE (Token Generation Event).
     */
    function claimTokens() external {
        User storage userData = users[msg.sender];
        require(isTgeActivated, "contract is not actives");
        require(userData.numberOfClaims > 0, "No claims to happen");


        uint256 elapsedTime = block.timestamp - tgeStartTime; // defino o tempo atual
        uint256 availableClaims = (elapsedTime / vestingInterval >= userData.numberOfClaims)
        ? userData.numberOfClaims : elapsedTime / vestingInterval; // quantidade de claims disponíveis até o momento
        
        uint256 claimableAmount = availableClaims * userData.tokensPerClaim;


        require(token.transfer(msg.sender, claimableAmount), "token Transfer faild");
        userData.numberOfClaims -= availableClaims;
        userData.claimedAmount += claimableAmount;

        emit TokensClaimed(msg.sender, claimableAmount);


    }

    /**
     * @dev Function to subscribe a user to the waitlist.
     */
    function subscribeToWaitList() external {
        require(!waitlist[msg.sender], "User is already in the waitlist");

        // Adiciona o usuário ao mapeamento e ao array de endereços da waitlist
        waitlist[msg.sender] = true;
        waitlistAddresses.push(msg.sender);

        emit SubscribedToWaitList(msg.sender);
    }

    /**
     * @dev Function to get the balance of the token in the contract.
     * @return The balance of the token.
     */
    function getBalanceToken() external view returns (uint256) {
        return token.balanceOf(address(this)); // Retorna o saldo de tokens X no contrato
    }

    /**
     * @dev Function to get the balance of the stablecoin in the contract.
     * @return The balance of the stablecoin.
     */
    function getBalanceStablecoin() external view returns (uint256) {
        return stablecoin.balanceOf(address(this)); // Retorna o saldo de tokens Y no contrato
    }

   
    /**
     * @dev Function to withdraw remaining tokens by the owner.
     */
    function withdrawRemainingTokens() external onlyOwner {
    // Transferir tokens remanescentes para o proprietário
        uint256 remainingTokens = token.balanceOf(address(this));
        require(remainingTokens > 0, "No remaining tokens to withdraw");
        require(token.transfer(owner(), remainingTokens), "Token transfer failed");
        
    }

    /**
     * @dev Function to withdraw deposited stablecoins by the owner.
     */
    function withdrawDepositedStablecoins() external onlyOwner {
    // Transferir stablecoins depositadas pelos usuários para o proprietário
        uint256 depositedStablecoins = stablecoin.balanceOf(address(this));
        require(depositedStablecoins > 0, "No deposited stablecoins to withdraw");
        require(stablecoin.transfer(owner(), depositedStablecoins), "Stablecoin transfer failed");
    }

    /**
     * @dev Function to update the fundraising goal.
     * @param _newGoal The new fundraising goal.
     */
    function updateFundraisingGoal(uint256 _newGoal) external onlyOwner {
        fundraising.fundraisingGoal = _newGoal;
    }

}

    
