// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";

contract KifukuStorage is Ownable {
    // Struktur untuk menyimpan informasi tentang token meme
    struct memeToken {
        string name;
        string symbol;
        string description;
        string tokenImageUrl;
        uint fundingRaised;
        address tokenAddress;
        address creatorAddress;
        string source; // Tambahan: untuk membedakan token dari Kifuku dan Kaemon
    }
    
    // Struktur untuk menyimpan informasi tentang voting
    struct Vote {
        uint voteCount;
        bool isVotingActive;
        uint256 startTime;
        uint256 endTime;
    }
    
    // Struktur untuk menyimpan informasi tentang staking
    struct Stake {
        uint amount;
        uint startTime;
    }
    
    // Struktur untuk menyimpan informasi tentang pemegang token
    struct TokenHolder {
        address holderAddress;
        uint256 balance;
    }
    
    // Array publik untuk menyimpan alamat semua token meme
    address[] public memeTokenAddresses;
    
    // Pemetaan dari alamat token ke struktur memeToken
    mapping(address => memeToken) public addressToMemeTokenMapping;
    
    // Pemetaan dari alamat token ke informasi voting
    mapping(address => Vote) public tokenVotes;
    
    // Array untuk menyimpan daftar token yang sedang divote
    address[] public votingTokens;
    
    // Pemetaan dari alamat pengguna ke informasi staking
    mapping(address => mapping(address => Stake)) public userTokenStakes;
    
    // Pemetaan untuk melacak siapa yang sudah memilih (mencegah double voting)
    mapping(bytes32 => bool) private _hasVoted;
    
    // Alamat kontrak utama yang diizinkan untuk memodifikasi storage
    address public coreContract;
    
    // Pemetaan untuk menyimpan spotlight percentage untuk setiap token
    mapping(address => uint256) public tokenSpotlightPercentage;
    
    constructor() {
        _transferOwnership(msg.sender);
    }
    
    /**
     * Fungsi untuk mengatur alamat kontrak utama
     * @param _coreContract Alamat kontrak utama
     */
    function setCoreContract(address _coreContract) external onlyOwner {
        require(_coreContract != address(0), "Invalid core contract address");
        coreContract = _coreContract;
    }
    
    /**
     * Modifier untuk membatasi akses hanya ke kontrak utama
     */
    modifier onlyCore() {
        require(msg.sender == coreContract, "Caller is not the core contract");
        _;
    }
    
    /**
     * Fungsi untuk menambahkan token meme baru
     * @param name Nama token
     * @param symbol Simbol token
     * @param description Deskripsi token
     * @param imageUrl URL gambar token
     * @param fundingRaised Jumlah dana yang terkumpul
     * @param tokenAddress Alamat kontrak token
     * @param creatorAddress Alamat pembuat token
     * @param source Sumber token (Kifuku atau Kaemon)
     */
    function addMemeToken(
        string memory name,
        string memory symbol,
        string memory description,
        string memory imageUrl,
        uint fundingRaised,
        address tokenAddress,
        address creatorAddress,
        string memory source
    ) external onlyCore {
        memeToken memory newlyCreatedToken = memeToken(
            name,
            symbol,
            description,
            imageUrl,
            fundingRaised,
            tokenAddress,
            creatorAddress,
            source
        );
        
        memeTokenAddresses.push(tokenAddress);
        addressToMemeTokenMapping[tokenAddress] = newlyCreatedToken;
    }
    
    /**
     * Fungsi untuk memperbarui informasi staking
     * @param user Alamat pengguna
     * @param tokenAddress Alamat token
     * @param amount Jumlah token yang di-stake
     * @param startTime Waktu mulai staking
     */
    function updateStake(address user, address tokenAddress, uint amount, uint startTime) external onlyCore {
        userTokenStakes[user][tokenAddress].amount += amount;
        userTokenStakes[user][tokenAddress].startTime = startTime;
    }
    
    /**
     * Fungsi untuk memperbarui waktu mulai staking
     * @param user Alamat pengguna
     * @param tokenAddress Alamat token
     * @param startTime Waktu mulai staking baru
     */
    function updateStakeTime(address user, address tokenAddress, uint startTime) external onlyCore {
        userTokenStakes[user][tokenAddress].startTime = startTime;
    }
    
    /**
     * Fungsi untuk menghapus informasi staking
     * @param user Alamat pengguna
     * @param tokenAddress Alamat token
     */
    function removeStake(address user, address tokenAddress) external onlyCore {
        delete userTokenStakes[user][tokenAddress];
    }
    
    /**
     * Fungsi untuk mengatur status voting
     * @param tokenAddress Alamat token
     * @param isActive Status voting
     * @param startTime Waktu mulai voting
     * @param endTime Waktu berakhir voting
     */
    function setVotingStatus(address tokenAddress, bool isActive, uint256 startTime, uint256 endTime) external onlyCore {
        tokenVotes[tokenAddress].isVotingActive = isActive;
        tokenVotes[tokenAddress].startTime = startTime;
        tokenVotes[tokenAddress].endTime = endTime;
    }
    
    /**
     * Fungsi untuk menambah jumlah vote
     * @param tokenAddress Alamat token
     */
    function incrementVoteCount(address tokenAddress) external onlyCore {
        tokenVotes[tokenAddress].voteCount += 1;
    }
    
    /**
     * Fungsi untuk menandai bahwa pengguna telah memilih
     * @param voteKey Kunci vote (hash dari alamat pengguna dan alamat token)
     */
    function setHasVoted(bytes32 voteKey) external onlyCore {
        _hasVoted[voteKey] = true;
    }
    
    /**
     * Fungsi untuk memeriksa apakah pengguna telah memilih
     * @param voteKey Kunci vote (hash dari alamat pengguna dan alamat token)
     * @return Status apakah pengguna telah memilih
     */
    function hasVoted(bytes32 voteKey) external view returns (bool) {
        return _hasVoted[voteKey];
    }
    
    /**
     * Fungsi untuk menambahkan token ke daftar voting
     * @param tokenAddress Alamat token
     */
    function addVotingToken(address tokenAddress) external onlyCore {
        votingTokens.push(tokenAddress);
    }
    
    /**
     * Fungsi untuk mengatur daftar token voting baru
     * @param newVotingTokens Array alamat token voting baru
     */
    function setVotingTokens(address[] memory newVotingTokens) external onlyCore {
        delete votingTokens;
        for (uint i = 0; i < newVotingTokens.length; i++) {
            votingTokens.push(newVotingTokens[i]);
        }
    }
    
    /**
     * Fungsi untuk mengatur spotlight percentage untuk token
     * @param tokenAddress Alamat token
     * @param percentage Persentase spotlight
     */
    function setTokenSpotlightPercentage(address tokenAddress, uint256 percentage) external onlyCore {
        require(percentage <= 100, "Percentage cannot exceed 100");
        tokenSpotlightPercentage[tokenAddress] = percentage;
    }
    
    /**
     * Fungsi untuk mendapatkan jumlah token meme
     * @return Jumlah token meme
     */
    function getMemeTokenCount() external view returns (uint) {
        return memeTokenAddresses.length;
    }
    
    /**
     * Fungsi untuk mendapatkan jumlah token voting
     * @return Jumlah token voting
     */
    function getVotingTokenCount() external view returns (uint) {
        return votingTokens.length;
    }

    // Fungsi untuk mendapatkan data token meme
    function getMemeTokenData(address tokenAddress) external view returns (
        string memory name,
        string memory symbol,
        string memory description,
        string memory tokenImageUrl,
        address memeTokenAddress,
        address creatorAddress,
        uint fundingRaised,
        string memory source
    ) {
        memeToken storage token = addressToMemeTokenMapping[tokenAddress];
        return (
            token.name,
            token.symbol,
            token.description,
            token.tokenImageUrl,
            token.tokenAddress,
            token.creatorAddress,
            token.fundingRaised,
            token.source
        );
    }

    // Fungsi untuk mendapatkan alamat semua token meme
    function getMemeTokenAddresses() external view returns (address[] memory) {
        return memeTokenAddresses;
    }
}