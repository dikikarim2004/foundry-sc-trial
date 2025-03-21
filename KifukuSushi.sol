// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import "./Token.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./KifukuStorage.sol";

// Interface untuk SushiSwap Factory
interface ISushiSwapFactory {
    function getPair(address tokenA, address tokenB) external view returns (address pair);
    function createPair(address tokenA, address tokenB) external returns (address pair);
}

// Interface untuk SushiSwap Router
interface ISushiSwapRouter {
    function factory() external pure returns (address);
    function WETH() external pure returns (address);
    
    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable returns (uint amountToken, uint amountETH, uint liquidity);
    
    function removeLiquidityETH(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external returns (uint amountToken, uint amountETH);
    
    function swapExactTokensForETH(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);

    function swapExactETHForTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable returns (uint[] memory amounts);
    
    function getAmountsOut(uint amountIn, address[] calldata path) external view returns (uint[] memory amounts);
}

// Interface untuk SushiSwap Pair
interface ISushiSwapPair {
    function token0() external view returns (address);
    function token1() external view returns (address);
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
    function balanceOf(address owner) external view returns (uint);
    function approve(address spender, uint value) external returns (bool);
}

contract KifukuSushi is ReentrancyGuard, Ownable {
    KifukuStorage public storageContract;
    
    // Alamat kontrak SushiSwap
    address public sushiSwapRouterAddress;
    address public sushiSwapFactoryAddress;
    
    // Event
    event LiquidityAdded(address indexed tokenAddress, uint amountToken, uint amountETH, uint liquidity);
    event TokenSold(address indexed seller, address indexed tokenAddress, uint amountIn, uint amountOut);
    event TokenPurchased(address indexed buyer, address indexed tokenAddress, uint amountIn, uint amountOut);
    
    /**
     * @dev Konstruktor kontrak
     * @param _storageAddress Alamat kontrak storage
     */
    constructor(address _storageAddress) {
        _transferOwnership(msg.sender);
        storageContract = KifukuStorage(_storageAddress);
        
        // Alamat SushiSwap Router dan Factory untuk Polygon zkEVM Testnet
        // Catatan: Alamat ini perlu diperbarui dengan alamat yang benar untuk Polygon zkEVM
        sushiSwapRouterAddress = 0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506; // Contoh alamat, perlu diperbarui
        sushiSwapFactoryAddress = 0xc35DADB65012eC5796536bD9864eD8773aBc74C4; // Contoh alamat, perlu diperbarui
    }
    
    /**
     * @dev Fungsi untuk mengatur alamat router SushiSwap
     * @param _routerAddress Alamat router SushiSwap
     */
    function setSushiSwapRouter(address _routerAddress) external onlyOwner {
        require(_routerAddress != address(0), "Invalid router address");
        sushiSwapRouterAddress = _routerAddress;
    }
    
    /**
     * @dev Fungsi untuk mengatur alamat factory SushiSwap
     * @param _factoryAddress Alamat factory SushiSwap
     */
    function setSushiSwapFactory(address _factoryAddress) external onlyOwner {
        require(_factoryAddress != address(0), "Invalid factory address");
        sushiSwapFactoryAddress = _factoryAddress;
    }
    
    /**
     * @dev Fungsi untuk menjual token melalui SushiSwap
     * @param memeTokenAddress Alamat token meme
     * @param tokenAmount Jumlah token yang akan dijual
     */
    function sellToPool(address memeTokenAddress, uint tokenAmount) external nonReentrant {
        require(memeTokenAddress != address(0), "Invalid token address");
        require(tokenAmount > 0, "Token amount must be greater than 0");
        
        Token token = Token(memeTokenAddress);
        
        // Verifikasi bahwa pengguna memiliki cukup token
        require(token.balanceOf(msg.sender) >= tokenAmount, "Insufficient token balance");
        
        ISushiSwapRouter router = ISushiSwapRouter(sushiSwapRouterAddress);
        
        // Pastikan pair ada
        ISushiSwapFactory factory = ISushiSwapFactory(sushiSwapFactoryAddress);
        address pairAddress = factory.getPair(memeTokenAddress, router.WETH());
        require(pairAddress != address(0), "Pair does not exist");
        
        // Approve router untuk menggunakan token
        require(token.transferFrom(msg.sender, address(this), tokenAmount), "Token transfer failed");
        require(token.approve(sushiSwapRouterAddress, tokenAmount), "Approval failed");
        
        // Siapkan parameter untuk swap
        address[] memory path = new address[](2);
        path[0] = memeTokenAddress;
        path[1] = router.WETH();
        
        // Deadline 5 menit dari sekarang
        uint deadline = block.timestamp + 300;
        
        // Hitung jumlah minimum ETH yang diharapkan (dengan slippage 5%)
        uint[] memory amounts = router.getAmountsOut(tokenAmount, path);
        uint minEth = amounts[1] * 95 / 100; // 5% slippage
        
        // Lakukan swap
        router.swapExactTokensForETH(
            tokenAmount,
            minEth,
            path,
            msg.sender,
            deadline
        );
        
        emit TokenSold(msg.sender, memeTokenAddress, tokenAmount, amounts[1]);
    }
    
    /**
     * @dev Fungsi internal untuk membuat pool likuiditas
     * @param memeTokenAddress Alamat token meme
     * @return Alamat pool yang dibuat
     */
    function _createLiquidityPool(address memeTokenAddress) internal returns (address) {
        ISushiSwapFactory factory = ISushiSwapFactory(sushiSwapFactoryAddress);
        ISushiSwapRouter router = ISushiSwapRouter(sushiSwapRouterAddress);
        
        // Periksa apakah pair sudah ada
        address pair = factory.getPair(memeTokenAddress, router.WETH());
        
        // Jika pair belum ada, buat pair baru
        if (pair == address(0)) {
            pair = factory.createPair(memeTokenAddress, router.WETH());
        }
        
        return pair;
    }
    
    /**
     * @dev Fungsi internal untuk menyediakan likuiditas
     * @param memeTokenAddress Alamat token meme
     * @param tokenAmount Jumlah token yang akan disediakan
     * @param ethAmount Jumlah ETH yang akan disediakan
     * @return Jumlah token LP yang diterima
     */
    function _provideLiquidity(address memeTokenAddress, uint tokenAmount, uint ethAmount) internal returns (uint) {
        require(memeTokenAddress != address(0), "Invalid token address");
        require(tokenAmount > 0, "Token amount must be greater than 0");
        require(ethAmount > 0, "ETH amount must be greater than 0");
        require(address(this).balance >= ethAmount, "Insufficient ETH balance");
        
        Token token = Token(memeTokenAddress);
        require(token.balanceOf(address(this)) >= tokenAmount, "Insufficient token balance");
        
        ISushiSwapRouter router = ISushiSwapRouter(sushiSwapRouterAddress);
        
        // Approve router untuk menggunakan token
        require(token.approve(sushiSwapRouterAddress, tokenAmount), "Approval failed");
        
        // Deadline 5 menit dari sekarang
        uint deadline = block.timestamp + 300;
        
        // Tambahkan likuiditas
        (uint amountToken, uint amountETH, uint liquidity) = router.addLiquidityETH{value: ethAmount}(
            memeTokenAddress,
            tokenAmount,
            tokenAmount * 95 / 100, // 5% slippage untuk token
            ethAmount * 95 / 100,   // 5% slippage untuk ETH
            address(this),          // LP token dikirim ke kontrak ini
            deadline
        );
        
        emit LiquidityAdded(memeTokenAddress, amountToken, amountETH, liquidity);
        
        return liquidity;
    }
    
    /**
     * @dev Fungsi internal untuk membakar token LP
     * @param pool Alamat pool likuiditas
     * @param liquidity Jumlah token LP yang akan dibakar
     * @return Jumlah ETH yang diterima
     */
    function _burnLpTokens(address pool, uint liquidity) internal returns (uint) {
        require(pool != address(0), "Invalid pool address");
        require(liquidity > 0, "Liquidity must be greater than 0");
        
        ISushiSwapPair pair = ISushiSwapPair(pool);
        require(pair.balanceOf(address(this)) >= liquidity, "Insufficient LP token balance");
        
        // Approve pair untuk menggunakan token LP
        require(pair.approve(sushiSwapRouterAddress, liquidity), "Approval failed");
        
        ISushiSwapRouter router = ISushiSwapRouter(sushiSwapRouterAddress);
        
        // Deadline 5 menit dari sekarang
        uint deadline = block.timestamp + 300;
        
        // Hapus likuiditas
        (, uint amountETH) = router.removeLiquidityETH(
            pair.token0() == router.WETH() ? pair.token1() : pair.token0(),
            liquidity,
            0, // Minimum token
            0, // Minimum ETH
            address(this),
            deadline
        );
        
        return amountETH;
    }
    
    /**
     * @dev Fungsi untuk menangani likuiditas (membuat pool, menyediakan likuiditas)
     * @param memeTokenAddress Alamat token meme
     * @param tokenAmount Jumlah token yang akan disediakan
     * @param ethAmount Jumlah ETH yang akan disediakan
     * @return Alam
      * @return Alamat pool dan jumlah token LP yang diterima
     */
    function handleLiquidity(address memeTokenAddress, uint tokenAmount, uint ethAmount) external payable onlyOwner returns (address, uint) {
        require(memeTokenAddress != address(0), "Invalid token address");
        require(tokenAmount > 0, "Token amount must be greater than 0");
        require(msg.value >= ethAmount, "Insufficient ETH sent");
        
        Token token = Token(memeTokenAddress);
        
        // Transfer token dari pengirim ke kontrak ini
        require(token.transferFrom(msg.sender, address(this), tokenAmount), "Token transfer failed");
        
        // Buat pool likuiditas jika belum ada
        address pool = _createLiquidityPool(memeTokenAddress);
        
        // Sediakan likuiditas
        uint liquidity = _provideLiquidity(memeTokenAddress, tokenAmount, ethAmount);
        
        // Kembalikan kelebihan ETH
        uint refundAmount = msg.value - ethAmount;
        if (refundAmount > 0) {
            (bool success, ) = payable(msg.sender).call{value: refundAmount}("");
            require(success, "Refund failed");
        }
        
        return (pool, liquidity);
    }
    
    /**
     * @dev Fungsi untuk mendapatkan informasi pool likuiditas
     * @param memeTokenAddress Alamat token meme
     * @return Alamat pool, reserve token, reserve ETH, dan jumlah token LP yang dimiliki kontrak
     */
    function getLiquidityPoolInfo(address memeTokenAddress) external view returns (address, uint, uint, uint) {
        require(memeTokenAddress != address(0), "Invalid token address");
        
        ISushiSwapRouter router = ISushiSwapRouter(sushiSwapRouterAddress);
        ISushiSwapFactory factory = ISushiSwapFactory(sushiSwapFactoryAddress);
        
        // Dapatkan alamat pool
        address pool = factory.getPair(memeTokenAddress, router.WETH());
        
        // Jika pool belum ada, kembalikan nilai default
        if (pool == address(0)) {
            return (address(0), 0, 0, 0);
        }
        
        ISushiSwapPair pair = ISushiSwapPair(pool);
        
        // Dapatkan reserve
        (uint112 reserve0, uint112 reserve1, ) = pair.getReserves();
        
        // Tentukan reserve token dan reserve ETH
        uint reserveToken;
        uint reserveETH;
        
        if (pair.token0() == memeTokenAddress) {
            reserveToken = reserve0;
            reserveETH = reserve1;
        } else {
            reserveToken = reserve1;
            reserveETH = reserve0;
        }
        
        // Dapatkan jumlah token LP yang dimiliki kontrak
        uint lpBalance = pair.balanceOf(address(this));
        
        return (pool, reserveToken, reserveETH, lpBalance);
    }

    /**
    * @dev Fungsi untuk membeli token melalui SushiSwap
    * @param memeTokenAddress Alamat token meme
    * @param ethAmount Jumlah ETH yang akan digunakan untuk membeli
    */
    function buyFromPool(address memeTokenAddress, uint ethAmount) external payable nonReentrant {
        require(memeTokenAddress != address(0), "Invalid token address");
        require(ethAmount > 0, "ETH amount must be greater than 0");
        require(msg.value >= ethAmount, "Not enough ETH sent");
        
        ISushiSwapRouter router = ISushiSwapRouter(sushiSwapRouterAddress);
        
        // Pastikan pair ada
        ISushiSwapFactory factory = ISushiSwapFactory(sushiSwapFactoryAddress);
        address pairAddress = factory.getPair(memeTokenAddress, router.WETH());
        require(pairAddress != address(0), "Pair does not exist");
        
        // Siapkan parameter untuk swap
        address[] memory path = new address[](2);
        path[0] = router.WETH();
        path[1] = memeTokenAddress;
        
        // Deadline 5 menit dari sekarang
        uint deadline = block.timestamp + 300;
        
        // Hitung jumlah minimum token yang diharapkan (dengan slippage 5%)
        uint[] memory amounts = router.getAmountsOut(ethAmount, path);
        uint minTokens = amounts[1] * 95 / 100; // 5% slippage
        
        // Lakukan swap
        router.swapExactETHForTokens{value: ethAmount}(
            minTokens,
            path,
            msg.sender,
            deadline
        );
        
        // Kembalikan ETH yang tidak digunakan
        uint refundAmount = msg.value - ethAmount;
        if (refundAmount > 0) {
            (bool success, ) = payable(msg.sender).call{value: refundAmount}("");
            require(success, "Refund failed");
        }
        
        emit TokenPurchased(msg.sender, memeTokenAddress, amounts[1], ethAmount);
    }
    
    /**
     * @dev Fungsi untuk menerima ETH
     */
    receive() external payable {
        // Memungkinkan kontrak menerima ETH
    }
}