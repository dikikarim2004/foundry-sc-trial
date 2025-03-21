// SPDX-License-Identifier: MIT


pragma solidity ^0.8.24;


import "./Token.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./KifukuStorage.sol";


contract KifukuStaking is ReentrancyGuard, Ownable {
    KifukuStorage public storageContract;
    
    // Konstanta untuk staking
    uint constant REWARD_RATE = 100; // 1% per hari
    
    // Event
    event Staked(address indexed user, address indexed tokenAddress, uint256 amount);
    event Unstaked(address indexed user, address indexed tokenAddress, uint256 amount);
    event RewardClaimed(address indexed user, address indexed tokenAddress, uint256 reward);
    
    /**
     * Konstruktor kontrak
     * @param _storageAddress Alamat kontrak storage
     */
    constructor(address _storageAddress) {
        _transferOwnership(msg.sender);
        storageContract = KifukuStorage(_storageAddress);
    }
    
    /**
    * Fungsi untuk staking.
    * @param amount Jumlah token yang akan di-stake.
    * @param memeTokenAddress Alamat token meme.
    */
    function stake(uint amount, address memeTokenAddress) public nonReentrant {
        require(amount > 0, "Stake amount must be greater than 0");
        require(memeTokenAddress != address(0), "Invalid token address");
        
        // Verifikasi token terdaftar
        (,,,,, address tokenAddr,,) = storageContract.addressToMemeTokenMapping(memeTokenAddress);
        require(tokenAddr == memeTokenAddress, "Token is not listed");
        
        Token memeTokenCt = Token(memeTokenAddress);
        require(memeTokenCt.balanceOf(msg.sender) >= amount, "Insufficient balance");
        require(memeTokenCt.transferFrom(msg.sender, address(this), amount), "Transfer failed");

        // Klaim reward terlebih dahulu jika sudah ada stake
        (uint256 stakeAmount,) = storageContract.userTokenStakes(msg.sender, memeTokenAddress);
        if (stakeAmount > 0) {
            claimReward(memeTokenAddress);
        }

        // Update stake di storage contract
        storageContract.updateStake(msg.sender, memeTokenAddress, amount, block.timestamp);
        
        emit Staked(msg.sender, memeTokenAddress, amount);
    }

    /**
    * Fungsi untuk unstaking.
    * @param memeTokenAddress Alamat token meme.
    */
    function unstake(address memeTokenAddress) public nonReentrant {
        require(memeTokenAddress != address(0), "Invalid token address");
        
        (uint256 stakeAmount,) = storageContract.userTokenStakes(msg.sender, memeTokenAddress);
        require(stakeAmount > 0, "No stake to unstake");

        uint amount = stakeAmount;
        claimReward(memeTokenAddress);

        Token memeTokenCt = Token(memeTokenAddress);
        require(memeTokenCt.transfer(msg.sender, amount), "Transfer failed");

        // Hapus stake di storage contract
        storageContract.removeStake(msg.sender, memeTokenAddress);
        
        emit Unstaked(msg.sender, memeTokenAddress, amount);
    }

    /**
    * Fungsi untuk menghitung dan mengklaim reward.
    * @param memeTokenAddress Alamat token meme.
    */
    function claimReward(address memeTokenAddress) public nonReentrant {
        require(memeTokenAddress != address(0), "Invalid token address");
        
        (uint256 stakeAmount,) = storageContract.userTokenStakes(msg.sender, memeTokenAddress);
        require(stakeAmount > 0, "No stake to claim reward");

        uint reward = calculateReward(memeTokenAddress);
        if (reward > 0) {
            // Update waktu mulai staking
            storageContract.updateStakeTime(msg.sender, memeTokenAddress, block.timestamp);

            Token memeTokenCt = Token(memeTokenAddress);
            bool success = memeTokenCt.mint(reward, msg.sender) == 1;
            require(success, "Mint failed");
            
            emit RewardClaimed(msg.sender, memeTokenAddress, reward);
        }
    }
    
    /**
    * Fungsi untuk menghitung reward staking.
    * @param memeTokenAddress Alamat token meme.
    * @return Jumlah reward yang dapat diklaim.
    */
    function calculateReward(address memeTokenAddress) public view returns (uint) {
        require(memeTokenAddress != address(0), "Invalid token address");
        
        (uint256 stakedAmount, uint256 startTime) = storageContract.userTokenStakes(msg.sender, memeTokenAddress);
        require(stakedAmount > 0, "No stake to calculate reward");

        uint timeElapsed = block.timestamp - startTime;
        uint daysElapsed = timeElapsed / 1 days;

        if (daysElapsed == 0) {
            return 0;
        }

        Token memeTokenCt = Token(memeTokenAddress);
        require(memeTokenCt.totalSupply() > 0, "Invalid token");

        return stakedAmount * REWARD_RATE * daysElapsed / 10000;
    }

    /**
    * Fungsi untuk mendapatkan informasi staking pengguna.
    * @param user Alamat pengguna.
    * @param memeTokenAddress Alamat token meme.
    * @return Jumlah token yang di-stake dan waktu mulai staking.
    */
    function getStakeInfo(address user, address memeTokenAddress) public view returns (uint, uint) {
        require(memeTokenAddress != address(0), "Invalid token address");
        
        return storageContract.userTokenStakes(user, memeTokenAddress);
    }

    /**
    * Fungsi untuk mendapatkan daftar pemegang stake untuk token tertentu.
    * @param memeTokenAddress Alamat token meme.
    * @param maxHolders Jumlah maksimum pemegang stake yang akan dikembalikan.
    * @return Array alamat pemegang stake dan array jumlah stake.
    */
    function getStakeHolders(address memeTokenAddress, uint maxHolders) public view returns (
        address[] memory, 
        uint256[] memory
    ) {
        require(memeTokenAddress != address(0), "Invalid token address");
        
        // Dapatkan semua alamat yang memiliki stake
        address[] memory allAddresses = new address[](storageContract.getMemeTokenCount() * 10); // Perkiraan ukuran
        uint256 holderCount = 0;
        
        // Periksa semua alamat yang mungkin memiliki stake
        for (uint i = 0; i < storageContract.getMemeTokenCount(); i++) {
            address potentialHolder = storageContract.memeTokenAddresses(i);
            (uint256 stakeAmount,) = storageContract.userTokenStakes(potentialHolder, memeTokenAddress);
            if (stakeAmount > 0) {
                allAddresses[holderCount] = potentialHolder;
                holderCount++;
            }
        }
        
        // Batasi jumlah pemegang stake yang dikembalikan
        uint256 resultCount = holderCount < maxHolders ? holderCount : maxHolders;
        address[] memory holders = new address[](resultCount);
        uint256[] memory amounts = new uint256[](resultCount);
        
        // Salin data ke array hasil
        for (uint i = 0; i < resultCount; i++) {
            holders[i] = allAddresses[i];
            (uint256 stakeAmount,) = storageContract.userTokenStakes(allAddresses[i], memeTokenAddress);
            amounts[i] = stakeAmount;
        }
        
        return (holders, amounts);
    }
}
