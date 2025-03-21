// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

contract KifukuMath {
    uint256 public constant INITIAL_PRICE = 100000000000000; // 0.0001 ETH
    uint256 public constant K = 5 * 10**15;
    uint constant MIN_PRICE = 100000000000000; // 0.00001 ETH
    uint256 public constant MAX_SUPPLY = 1000000 * 10**18; // 1 million tokens
    uint256 public constant INIT_SUPPLY = 100000 * 10**18; // 100,000 tokens
    uint256 public constant DECIMALS = 10**18;
    
    /**
     * Fungsi untuk menghitung biaya pembelian token berdasarkan bonding curve eksponensial.
     * @param currentSupply Pasokan token saat ini.
     * @param tokensToBuy Jumlah token yang ingin dibeli.
     * @return Biaya dalam wei untuk membeli token.
     */
    function calculateCost(uint256 currentSupply, uint256 tokensToBuy) public pure returns (uint256) {
        require(tokensToBuy > 0, "Tokens to buy must be greater than 0");
        
        uint256 exponent1 = (K * (currentSupply + tokensToBuy)) / 10**18;
        uint256 exponent2 = (K * currentSupply) / 10**18;

        uint256 exp1 = exp(exponent1);
        uint256 exp2 = exp(exponent2);

        uint256 cost = (INITIAL_PRICE * (exp1 - exp2)) / K;
        cost = cost > MIN_PRICE ? cost : MIN_PRICE;

        return cost;
    }
    
    /**
     * Fungsi untuk menghitung nilai eksponensial menggunakan deret Taylor.
     * @param x Nilai input untuk perhitungan eksponensial.
     * @return Hasil eksponensial.
     */
    function exp(uint256 x) internal pure returns (uint256) {
        if (x > 50 * 10**18) {
            return type(uint256).max;
        }
        
        uint256 sum = 10**18;
        uint256 term = 10**18;
        uint256 xPower = x;

        for (uint256 i = 1; i <= 30; i++) {
            term = (term * xPower) / (i * 10**18);
            sum += term;

            if (term < 1) break;
        }

        return sum;
    }
    
    /**
     * Fungsi untuk menghitung persentase bonding curve
     * @param currentSupply Pasokan token saat ini
     * @param maxSupply Pasokan token maksimum
     * @return Persentase bonding curve (0-100)
     */
    function calculateBondingCurvePercentage(uint256 currentSupply, uint256 maxSupply) public pure returns (uint256) {
        require(maxSupply > 0, "Max supply must be greater than 0");
        
        // Persentase dihitung sebagai (currentSupply / maxSupply) * 100
        if (currentSupply >= maxSupply) {
            return 100;
        }
        
        return (currentSupply * 100) / maxSupply;
    }
    
    /**
     * Fungsi untuk menghitung harga token berdasarkan persentase bonding curve
     * @param percentage Persentase bonding curve (0-100)
     * @return Harga token dalam wei
     */
    function calculatePriceFromPercentage(uint256 percentage) public pure returns (uint256) {
        require(percentage <= 100, "Percentage cannot exceed 100");
        
        // Konversi persentase ke nilai antara 0 dan 1
        uint256 normalizedPercentage = percentage * 10**18 / 100;
        
        // Hitung harga menggunakan fungsi eksponensial
        uint256 exponent = (K * normalizedPercentage) / 10**18;
        uint256 price = (INITIAL_PRICE * exp(exponent)) / 10**18;
        
        price = price > MIN_PRICE ? price : MIN_PRICE;
        
        return price;
    }
}