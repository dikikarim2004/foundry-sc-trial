// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Token is ERC20, ERC20Burnable, Ownable {
    // Metadata token
    string private _description;
    string private _imageUrl;
    
    /**
     * @dev Konstruktor untuk membuat token baru
     * @param name Nama token
     * @param symbol Simbol token
     * @param initialMintValue Jumlah token yang akan di-mint pada awalnya
     */
    constructor(string memory name, string memory symbol, uint initialMintValue) 
        ERC20(name, symbol) 
    {
        _transferOwnership(msg.sender);
        _mint(msg.sender, initialMintValue);
        
        // Inisialisasi metadata dengan nilai default
        _description = "";
        _imageUrl = "";
    }
    
    /**
     * @dev Fungsi untuk mencetak token baru
     * @param mintQty Jumlah token yang akan dicetak
     * @param receiver Alamat penerima token
     * @return Nilai 1 untuk kompatibilitas dengan versi sebelumnya
     */
    function mint(uint mintQty, address receiver) external onlyOwner returns(uint) {
        _mint(receiver, mintQty);
        return 1;
    }
    
    /**
     * @dev Fungsi untuk membakar token
     * @param amount Jumlah token yang akan dibakar
     */
    function burn(uint256 amount) public override {
        super.burn(amount);
    }
    
    /**
     * @dev Fungsi untuk membakar token dari alamat tertentu
     * @param account Alamat yang tokennya akan dibakar
     * @param amount Jumlah token yang akan dibakar
     */
    function burnFrom(address account, uint256 amount) public override {
        super.burnFrom(account, amount);
    }
    
    /**
     * @dev Fungsi untuk mengatur deskripsi token
     * @param newDescription Deskripsi baru untuk token
     */
    function setDescription(string memory newDescription) external onlyOwner {
        _description = newDescription;
    }
    
    /**
     * @dev Fungsi untuk mengatur URL gambar token
     * @param newImageUrl URL gambar baru untuk token
     */
    function setImageUrl(string memory newImageUrl) external onlyOwner {
        _imageUrl = newImageUrl;
    }
    
    /**
     * @dev Fungsi untuk mendapatkan deskripsi token
     * @return Deskripsi token
     */
    function description() external view returns (string memory) {
        return _description;
    }
    
    /**
     * @dev Fungsi untuk mendapatkan URL gambar token
     * @return URL gambar token
     */
    function imageUrl() external view returns (string memory) {
        return _imageUrl;
    }
}