// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title KifukuFactory
 * @dev Kontrak untuk men-deploy dan menginisialisasi semua kontrak Kifuku
 */
contract KifukuFactory is Ownable {
    // Alamat kontrak yang di-deploy
    address public storageAddress;
    address public mathAddress;
    address public coreAddress;
    address public uniswapAddress;
    address public governanceAddress;
    address public stakingAddress;
    
    // Event untuk pelacakan deployment
    event ContractDeployed(string contractName, address contractAddress);
    event DeploymentCompleted();
    
    /**
     * Konstruktor kontrak
     */
    constructor() {
        _transferOwnership(msg.sender);
    }
    
    /**
     * @dev Menyimpan alamat kontrak yang sudah di-deploy secara manual
     */
    function registerContracts(
        address _storage,
        address _math,
        address _core,
        address _uniswap,
        address _governance,
        address _staking
    ) external onlyOwner {
        storageAddress = _storage;
        mathAddress = _math;
        coreAddress = _core;
        uniswapAddress = _uniswap;
        governanceAddress = _governance;
        stakingAddress = _staking;
        
        emit DeploymentCompleted();
    }
    
    /**
     * @dev Transfer kepemilikan kontrak
     */
    function transferContractOwnership(address contractAddress) external onlyOwner {
        Ownable(contractAddress).transferOwnership(msg.sender);
    }
    
    /**
     * @dev Set core contract di storage
     */
    function setCoreInStorage() external onlyOwner {
        require(storageAddress != address(0), "Storage not set");
        require(coreAddress != address(0), "Core not set");
        
        // Panggil fungsi setCoreContract di storage
        (bool success,) = storageAddress.call(
            abi.encodeWithSignature("setCoreContract(address)", coreAddress)
        );
        require(success, "Failed to set core in storage");
    }
}