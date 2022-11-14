//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

contract FuelToken is ERC20, ERC20Burnable, Ownable {
    uint256 public maxSupply = 10000*10**18;

    constructor(
    ) ERC20("ABIToken","$ABI") {
    }

    function mint(address to, uint256 amount) external onlyOwner {
        require(maxSupply > totalSupply(), "Token Supply Exceeded");
        _mint(to, amount);
    }

    function burnFrom(address account, uint256 amount) public override {
        if (msg.sender == owner()) {
            _burn(account, amount);
        } else {
            super.burnFrom(account, amount);
        }
    }
}
