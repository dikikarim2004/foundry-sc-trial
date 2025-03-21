// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./KifukuStorage.sol";

contract KifukuGovernance is Ownable, ReentrancyGuard {
    KifukuStorage public storageContract;
    
    // Konstanta untuk voting
    uint256 public constant VOTING_DURATION = 7 days;
    uint256 public constant MIN_VOTES_REQUIRED = 10;
    
    // Event
    event VotingStarted(address indexed tokenAddress, uint256 startTime, uint256 endTime);
    event VoteCast(address indexed voter, address indexed tokenAddress);
    event VotingEnded(address indexed tokenAddress, uint256 voteCount, bool passed);
    
    /**
     * Konstruktor kontrak
     * @param _storageAddress Alamat kontrak storage
     */
    constructor(address _storageAddress) {
        _transferOwnership(msg.sender);
        storageContract = KifukuStorage(_storageAddress);
    }
    
    /**
     * Fungsi untuk memulai voting untuk token meme
     * @param memeTokenAddress Alamat token meme
     */
    function startVoting(address memeTokenAddress) external onlyOwner {
        // Verifikasi token terdaftar
        (,,,,, address tokenAddr,,) = storageContract.addressToMemeTokenMapping(memeTokenAddress);
        require(tokenAddr == memeTokenAddress, "Token is not listed");
        
        // Verifikasi token tidak sedang dalam voting
        (, bool isVotingActive,,) = storageContract.tokenVotes(memeTokenAddress);
        require(!isVotingActive, "Voting already active for this token");
        
        uint256 startTime = block.timestamp;
        uint256 endTime = startTime + VOTING_DURATION;
        
        // Atur status voting
        storageContract.setVotingStatus(memeTokenAddress, true, startTime, endTime);
        
        // Tambahkan token ke daftar voting
        storageContract.addVotingToken(memeTokenAddress);
        
        emit VotingStarted(memeTokenAddress, startTime, endTime);
    }
    
    /**
     * Fungsi untuk memberikan suara pada token
     * @param memeTokenAddress Alamat token meme
     */
    function vote(address memeTokenAddress) external nonReentrant {
        // Verifikasi token terdaftar
        (,,,,, address tokenAddr,,) = storageContract.addressToMemeTokenMapping(memeTokenAddress);
        require(tokenAddr == memeTokenAddress, "Token is not listed");
        
        // Dapatkan informasi voting
        (, bool isVotingActive, uint256 startTime, uint256 endTime) = storageContract.tokenVotes(memeTokenAddress);
        
        // Verifikasi voting aktif
        require(isVotingActive, "Voting is not active for this token");
        require(block.timestamp >= startTime && block.timestamp <= endTime, "Voting period has ended or not started");
        
        // Verifikasi pengguna belum memilih
        bytes32 voteKey = keccak256(abi.encodePacked(msg.sender, memeTokenAddress));
        require(!storageContract.hasVoted(voteKey), "Already voted for this token");
        
        // Catat suara
        storageContract.incrementVoteCount(memeTokenAddress);
        storageContract.setHasVoted(voteKey);
        
        emit VoteCast(msg.sender, memeTokenAddress);
    }
    
    /**
     * Fungsi untuk mengakhiri voting
     * @param memeTokenAddress Alamat token meme
     */
    function endVoting(address memeTokenAddress) external onlyOwner {
        // Verifikasi token terdaftar
        (,,,,, address tokenAddr,,) = storageContract.addressToMemeTokenMapping(memeTokenAddress);
        require(tokenAddr == memeTokenAddress, "Token is not listed");
        
        // Dapatkan informasi voting
        (uint256 voteCount, bool isVotingActive,, uint256 endTime) = storageContract.tokenVotes(memeTokenAddress);
        
        // Verifikasi voting aktif
        require(isVotingActive, "Voting is not active for this token");
        
        // Verifikasi periode voting telah berakhir atau dipercepat oleh admin
        require(block.timestamp > endTime || msg.sender == owner(), "Voting period has not ended");
        
        // Tentukan apakah voting berhasil
        bool passed = voteCount >= MIN_VOTES_REQUIRED;
        
        // Atur status voting menjadi tidak aktif
        storageContract.setVotingStatus(memeTokenAddress, false, 0, 0);
        
        // Perbarui daftar token voting
        address[] memory currentVotingTokens = new address[](storageContract.getVotingTokenCount());
        uint newCount = 0;
        
        for (uint i = 0; i < storageContract.getVotingTokenCount(); i++) {
            address tokenAddress = storageContract.votingTokens(i);
            if (tokenAddress != memeTokenAddress) {
                currentVotingTokens[newCount] = tokenAddress;
                newCount++;
            }
        }
        
        // Buat array baru dengan ukuran yang tepat
        address[] memory newVotingTokens = new address[](newCount);
        for (uint i = 0; i < newCount; i++) {
            newVotingTokens[i] = currentVotingTokens[i];
        }
        
        // Perbarui daftar token voting
        storageContract.setVotingTokens(newVotingTokens);
        
        emit VotingEnded(memeTokenAddress, voteCount, passed);
    }
    
    /**
     * Fungsi untuk mendapatkan daftar token yang sedang dalam voting
     * @return Array alamat token yang sedang dalam voting
     */
    function getActiveVotingTokens() external view returns (address[] memory) {
        uint count = 0;
        
        // Hitung jumlah token dengan voting aktif
        for (uint i = 0; i < storageContract.getVotingTokenCount(); i++) {
            address tokenAddress = storageContract.votingTokens(i);
            (, bool isVotingActive,,) = storageContract.tokenVotes(tokenAddress);
            if (isVotingActive) {
                count++;
            }
        }
        
        // Buat array dengan ukuran yang tepat
        address[] memory activeTokens = new address[](count);
        uint index = 0;
        
        // Isi array dengan alamat token yang memiliki voting aktif
        for (uint i = 0; i < storageContract.getVotingTokenCount(); i++) {
            address tokenAddress = storageContract.votingTokens(i);
            (, bool isVotingActive,,) = storageContract.tokenVotes(tokenAddress);
            if (isVotingActive) {
                activeTokens[index] = tokenAddress;
                index++;
            }
        }
        
        return activeTokens;
    }
    
    /**
     * Fungsi untuk mendapatkan informasi voting untuk token
     * @param memeTokenAddress Alamat token meme
     * @return Jumlah suara, status aktif, waktu mulai, waktu berakhir
     */
    function getVotingInfo(address memeTokenAddress) external view returns (uint, bool, uint256, uint256) {
        return storageContract.tokenVotes(memeTokenAddress);
    }
    
    /**
     * Fungsi untuk memeriksa apakah pengguna telah memilih untuk token tertentu
     * @param user Alamat pengguna
     * @param memeTokenAddress Alamat token meme
     * @return Status apakah pengguna telah memilih
     */
    function hasUserVoted(address user, address memeTokenAddress) external view returns (bool) {
        bytes32 voteKey = keccak256(abi.encodePacked(user, memeTokenAddress));
        return storageContract.hasVoted(voteKey);
    }
}