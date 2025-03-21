// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import "./Token.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./KifukuStorage.sol";
import "./KifukuMath.sol";

contract KifukuCore is ReentrancyGuard, Ownable {
    KifukuStorage public storageContract;
    KifukuMath public mathContract;
    
    // Konstanta untuk biaya platform dan parameter lainnya
    uint constant MEMETOKEN_CREATION_PLATFORM_FEE = 0.00005 ether;
    uint constant MEMECOIN_FUNDING_DEADLINE_DURATION = 10 days;
    uint constant MEMECOIN_FUNDING_GOAL = 0.01 ether;
    uint constant DECIMALS = 10 ** 18;
    uint constant MAX_SUPPLY = 100000 * DECIMALS;
    uint constant INIT_SUPPLY = 5 * MAX_SUPPLY / 100;

    struct TokenInfo {
        string name;
        string symbol;
        string description;
        string imageUrl;
        uint fundingRaised;
        address creatorAddress;
        string source;
    }
    
    // Event
    event MemeTokenCreated(address indexed tokenAddress, string name, string symbol, address indexed creator, string source);
    event TokenPurchased(address indexed buyer, address indexed tokenAddress, uint256 amount, uint256 cost);
    
    /**
     * Konstruktor kontrak
     * @param _storageAddress Alamat kontrak storage
     * @param _mathAddress Alamat kontrak math
     */
    constructor(address _storageAddress, address _mathAddress) {
        _transferOwnership(msg.sender);
        storageContract = KifukuStorage(_storageAddress);
        mathContract = KifukuMath(_mathAddress);
    }
    
    /**
     * Fungsi untuk membuat token meme baru
     * @param name Nama token
     * @param symbol Simbol token
     * @param imageUrl URL gambar token
     * @param description Deskripsi token
     * @param source Sumber token (Kifuku atau Kaemon)
     * @return Alamat kontrak token yang dibuat
     */
    function createMemeToken(
        string memory name,
        string memory symbol,
        string memory imageUrl,
        string memory description,
        string memory source
    ) public payable nonReentrant returns (address) {
        require(bytes(name).length > 0, "Name cannot be empty");
        require(bytes(symbol).length > 0, "Symbol cannot be empty");
        require(msg.value >= MEMETOKEN_CREATION_PLATFORM_FEE, "Fee not paid for memetoken creation");
        require(bytes(source).length > 0, "Source cannot be empty");

        Token ct = new Token(name, symbol, INIT_SUPPLY);
        address memeTokenAddress = address(ct);
        
        // Setelah token dibuat, atur metadata token
        ct.setDescription(description);
        ct.setImageUrl(imageUrl);

        storageContract.addMemeToken(
            name,
            symbol,
            description,
            imageUrl,
            0,
            memeTokenAddress,
            msg.sender,
            source
        );

        // Set default spotlight percentage (misalnya 50%)
        storageContract.setTokenSpotlightPercentage(memeTokenAddress, 50);

        emit MemeTokenCreated(memeTokenAddress, name, symbol, msg.sender, source);
        return memeTokenAddress;
    }
    
    /**
     * Fungsi untuk membeli token meme
     * @param memeTokenAddress Alamat token meme
     * @param tokenQty Jumlah token yang akan dibeli
     * @return Status keberhasilan (1 = berhasil)
     */
    function buyMemeToken(address memeTokenAddress, uint tokenQty) public payable nonReentrant returns (uint) {
        require(tokenQty > 0, "Token quantity must be greater than 0");
        require(memeTokenAddress != address(0), "Invalid token address");
        
        // Verifikasi token terdaftar - perbaikan error
        // Dapatkan informasi token dan periksa alamat token
        (,,,,, address tokenAddr,,) = storageContract.addressToMemeTokenMapping(memeTokenAddress);
        require(tokenAddr == memeTokenAddress, "Token is not listed");

        Token memeTokenCt = Token(memeTokenAddress);
        uint currentSupply = memeTokenCt.totalSupply();
        uint currentSupplyScaled = currentSupply > INIT_SUPPLY ? (currentSupply - INIT_SUPPLY) / DECIMALS : 0;
        
        uint ethToAdd = mathContract.calculateCost(currentSupplyScaled, tokenQty);
        require(msg.value >= ethToAdd, "Not enough ETH sent");

        // Mint token untuk pembeli
        memeTokenCt.mint(tokenQty * DECIMALS, msg.sender);

        uint refundAmount = msg.value - ethToAdd;
        if (refundAmount > 0) {
            (bool success, ) = payable(msg.sender).call{value: refundAmount}("");
            require(success, "Refund failed");
        }

        emit TokenPurchased(msg.sender, memeTokenAddress, tokenQty * DECIMALS, ethToAdd);

        return 1;
    }
    
    /**
     * Fungsi untuk mendapatkan daftar token berdasarkan sumber
     * @param source Sumber token (Kifuku atau Kaemon)
     * @return Array alamat token yang sesuai dengan sumber
     */
    function getTokensBySource(string memory source) public view returns (address[] memory) {
        uint count = 0;
        
        // Hitung jumlah token dengan sumber yang sesuai
        for (uint i = 0; i < storageContract.getMemeTokenCount(); i++) {
            address tokenAddress = storageContract.memeTokenAddresses(i);
            (,,,,,,, string memory tokenSource) = storageContract.addressToMemeTokenMapping(tokenAddress);
            
            if (keccak256(bytes(tokenSource)) == keccak256(bytes(source))) {
                count++;
            }
        }
        
        // Buat array dengan ukuran yang tepat
        address[] memory result = new address[](count);
        uint index = 0;
        
        // Isi array dengan alamat token yang sesuai
        for (uint i = 0; i < storageContract.getMemeTokenCount(); i++) {
            address tokenAddress = storageContract.memeTokenAddresses(i);
            (,,,,,,, string memory tokenSource) = storageContract.addressToMemeTokenMapping(tokenAddress);
            if (keccak256(bytes(tokenSource)) == keccak256(bytes(source))) {
                result[index] = tokenAddress;
                index++;
            }
        }
        
        return result;
    }
    
    /**
     * Fungsi untuk mendapatkan informasi token
     * @param tokenAddress Alamat token
     * @return Informasi token (nama, simbol, deskripsi, imageUrl, fundingRaised, creatorAddress, source)
     */
    function getTokenInfo(address tokenAddress) public view returns (
        TokenInfo memory
    ) {
        (
            string memory name,
            string memory symbol,
            string memory description,
            string memory imageUrl,
            uint fundingRaised,
            ,
            address creatorAddress,
            string memory source
        ) = storageContract.addressToMemeTokenMapping(tokenAddress);
        
        return TokenInfo({
            name: name,
            symbol: symbol,
            description: description,
            imageUrl: imageUrl,
            fundingRaised: fundingRaised,
            creatorAddress: creatorAddress,
            source: source
        });
    }
    
    /**
     * Fungsi untuk mendapatkan daftar pemegang token untuk token tertentu
     * @param tokenAddress Alamat token
     * @param maxHolders Jumlah maksimum pemegang token yang akan dikembalikan
     * @return Array alamat pemegang token dan array saldo token
     */
    function getTokenHolders(address tokenAddress, uint maxHolders) public view returns (
        address[] memory, 
        uint256[] memory
    ) {
        require(tokenAddress != address(0), "Invalid token address");
        
        Token token = Token(tokenAddress);
        uint256 totalSupply = token.totalSupply();
        require(totalSupply > 0, "Token has no supply");
        
        // Dapatkan semua alamat yang memiliki token
        address[] memory allAddresses = new address[](storageContract.getMemeTokenCount() * 10); // Perkiraan ukuran
        uint256 holderCount = 0;
        
        // Periksa semua alamat yang mungkin memiliki token
        // Catatan: Ini adalah pendekatan sederhana, implementasi yang lebih baik akan menggunakan event Transfer
        for (uint i = 0; i < storageContract.getMemeTokenCount(); i++) {
            address potentialHolder = storageContract.memeTokenAddresses(i);
            uint256 balance = token.balanceOf(potentialHolder);
            if (balance > 0) {
                allAddresses[holderCount] = potentialHolder;
                holderCount++;
            }
        }
        
        // Batasi jumlah pemegang token yang dikembalikan
        uint256 resultCount = holderCount < maxHolders ? holderCount : maxHolders;
        address[] memory holders = new address[](resultCount);
        uint256[] memory balances = new uint256[](resultCount);
        
        // Salin data ke array hasil
        for (uint i = 0; i < resultCount; i++) {
            holders[i] = allAddresses[i];
            balances[i] = token.balanceOf(allAddresses[i]);
        }
        
        return (holders, balances);
    }
    
    /**
     * Fungsi untuk mendapatkan persentase distribusi token untuk setiap pemegang
     * @param tokenAddress Alamat token
     * @param maxHolders Jumlah maksimum pemegang token yang akan dikembalikan
     * @return Array alamat pemegang token dan array persentase kepemilikan
     */
    function getTokenDistribution(address tokenAddress, uint maxHolders) public view returns (
        address[] memory, 
        uint256[] memory
    ) {
        require(tokenAddress != address(0), "Invalid token address");
        
        Token token = Token(tokenAddress);
        uint256 totalSupply = token.totalSupply();
        require(totalSupply > 0, "Token has no supply");
        
        // Dapatkan daftar pemegang token
        (address[] memory holders, uint256[] memory balances) = getTokenHolders(tokenAddress, maxHolders);
        
        // Hitung persentase untuk setiap pemegang
        uint256[] memory percentages = new uint256[](holders.length);
        for (uint i = 0; i < holders.length; i++) {
            // Persentase dihitung sebagai (balance / totalSupply) * 100 * 100 (untuk 2 desimal)
            percentages[i] = (balances[i] * 10000) / totalSupply;
        }
        
        return (holders, percentages);
    }
    
    /**
     * Fungsi untuk mengatur spotlight percentage untuk token
     * @param tokenAddress Alamat token
     * @param percentage Persentase spotlight (0-100)
     */
    function setTokenSpotlightPercentage(address tokenAddress, uint256 percentage) public onlyOwner {
        require(tokenAddress != address(0), "Invalid token address");
        require(percentage <= 100, "Percentage cannot exceed 100");
        
        storageContract.setTokenSpotlightPercentage(tokenAddress, percentage);
    }
    
    /**
     * Fungsi untuk mendapatkan spotlight percentage untuk token
     * @param tokenAddress Alamat token
     * @return Persentase spotlight
     */
    function getTokenSpotlightPercentage(address tokenAddress) public view returns (uint256) {
        require(tokenAddress != address(0), "Invalid token address");
        return storageContract.tokenSpotlightPercentage(tokenAddress);
    }

    // Struktur untuk informasi token meme
    struct MemeTokenInfo {
        string name;
        string symbol;
        string description;
        string tokenImageUrl;
        address tokenAddress;
        address creatorAddress;
        uint fundingRaised;
        uint availableSupply;
        uint currentPrice;
        string source; // Kolom baru untuk menunjukkan sumber token
    }

    /**
    * Fungsi untuk mendapatkan daftar semua token meme.
    * @param page Nomor halaman.
    * @param pageSize Ukuran halaman.
    * @return Array informasi token meme.
    */
    function getAllMemeTokens(uint page, uint pageSize) public view returns (MemeTokenInfo[] memory) {
        require(pageSize > 0, "Page size must be greater than 0");
        require(page > 0, "Page number must be greater than 0");

        // Dapatkan data dari storage
        address[] memory tokenAddresses = storageContract.getMemeTokenAddresses();
        
        uint startIdx = (page - 1) * pageSize;
        uint endIdx = startIdx + pageSize;

        if (endIdx > tokenAddresses.length) {
            endIdx = tokenAddresses.length;
        }

        if (startIdx >= tokenAddresses.length) {
            return new MemeTokenInfo[](0);
        }

        uint resultLength = endIdx - startIdx;
        MemeTokenInfo[] memory tokensInfo = new MemeTokenInfo[](resultLength);

        for (uint i = startIdx; i < endIdx; i++) {
            address memeTokenAddress = memeTokenAddresses[i];
            
            // Dapatkan data token dari storage
            (
                string memory name,
                string memory symbol,
                string memory description,
                string memory tokenImageUrl,
                address tokenAddress,
                address creatorAddress,
                uint fundingRaised,
                string memory source
            ) = storageContract.getMemeTokenData(memeTokenAddress);
            
            // Proses data token
            _processTokenInfo(
                tokensInfo, 
                i - startIdx, 
                name, 
                symbol, 
                description, 
                tokenImageUrl, 
                tokenAddress, 
                creatorAddress, 
                fundingRaised, 
                source
            );
        }

        return tokensInfo;
    }

    // Helper function to process token info and avoid stack too deep error
    function _processTokenInfo(
        MemeTokenInfo[] memory tokensInfo,
        uint index,
        string memory name,
        string memory symbol,
        string memory description,
        string memory tokenImageUrl,
        address tokenAddress,
        address creatorAddress,
        uint fundingRaised,
        string memory source
    ) private view {
        Token memeTokenCt = Token(tokenAddress);
        uint currentSupply = memeTokenCt.totalSupply();
        uint availableSupply = mathContract.MAX_SUPPLY() - currentSupply;

        // Hitung pasokan yang disesuaikan untuk harga token
        uint currentSupplyScaled = currentSupply > mathContract.INIT_SUPPLY() ? 
            (currentSupply - mathContract.INIT_SUPPLY()) / mathContract.DECIMALS() : 0;

        // Hitung harga token saat ini
        uint currentPrice = mathContract.calculateCost(currentSupplyScaled, 1); // Harga untuk 1 token

        tokensInfo[index] = MemeTokenInfo({
            name: name,
            symbol: symbol,
            description: description,
            tokenImageUrl: tokenImageUrl,
            tokenAddress: tokenAddress,
            creatorAddress: creatorAddress,
            fundingRaised: fundingRaised,
            availableSupply: availableSupply,
            currentPrice: currentPrice,
            source: source
        });
    }

    struct memeToken {
        string name;
        string symbol;
        address tokenAddress;
        uint createdAt;
        string tokenImageUrl;
        bool isListed;
    }

    address[] public memeTokenAddresses;

    mapping(address => memeToken) public addressToMemeTokenMapping;

    /**  
    * Fungsi untuk mendapatkan token yang dimiliki pengguna dengan pagination dan informasi tambahan.  
    * @param user Alamat pengguna.  
    * @param page Nomor halaman.  
    * @param pageSize Ukuran halaman.  
    * @return Nama, simbol, alamat, saldo, harga saat ini, waktu update, dan URL gambar token yang dimiliki pengguna.  
    */  
    struct UserTokenInfo {  
        string name;  
        string symbol;  
        address tokenAddress;  
        uint balance;  
        uint currentPrice;  
        uint updatedAt;  
        string tokenImageUrl;  
    }  

    function getUserTokens(address user, uint page, uint pageSize) public view returns (UserTokenInfo[] memory) {  
        require(pageSize > 0, "Page size must be greater than 0");  
        require(page > 0, "Page number must be greater than 0");  

        uint count = 0;  
        for (uint i = 0; i < memeTokenAddresses.length; i++) {  
            Token memeTokenCt = Token(memeTokenAddresses[i]);  
            if (memeTokenCt.balanceOf(user) > 0) {  
                count++;  
            }  
        }  

        uint startIdx = (page - 1) * pageSize;  
        uint endIdx = startIdx + pageSize;  
        if (endIdx > count) {  
            endIdx = count;  
        }  

        if (startIdx >= count) {  
            return new UserTokenInfo[](0);  
        }  

        UserTokenInfo[] memory tokensInfo = new UserTokenInfo[](endIdx - startIdx);  
        uint index = 0;  
        uint resultIndex = 0;  

        for (uint i = 0; i < memeTokenAddresses.length; i++) {  
            Token memeTokenCt = Token(memeTokenAddresses[i]);  
            uint balance = memeTokenCt.balanceOf(user);  
            if (balance > 0) {  
                if (index >= startIdx && index < endIdx) {  
                    address memeTokenAddress = memeTokenAddresses[i];  
                    memeToken storage listedToken = addressToMemeTokenMapping[memeTokenAddress];  

                    uint currentSupply = memeTokenCt.totalSupply();  
                    uint currentSupplyScaled = currentSupply > INIT_SUPPLY ? (currentSupply - INIT_SUPPLY) / DECIMALS : 0;  
                    uint currentPrice = mathContract.calculateCost(currentSupplyScaled, 1);  

                    tokensInfo[resultIndex] = UserTokenInfo({  
                        name: memeTokenCt.name(),  
                        symbol: memeTokenCt.symbol(),  
                        tokenAddress: memeTokenAddress,  
                        balance: balance,  
                        currentPrice: currentPrice,  
                        updatedAt: block.timestamp,  
                        tokenImageUrl: listedToken.tokenImageUrl  
                    });  
                    resultIndex++;  
                }  
                index++;  
            }  
        }  

        return tokensInfo;  
    }
    
    /**
     * Fungsi untuk menerima ETH
     */
    receive() external payable {
        // Memungkinkan kontrak menerima ETH
    }
}