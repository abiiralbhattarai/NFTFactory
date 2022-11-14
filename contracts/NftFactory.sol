//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./NftCollection.sol";

contract NftFactory {
    address private owner;
    NftCollection[] public createdNftArray; //addressess of crated array
    mapping(string => address) public createdAddress;

    NftCollection public nftCreate;

    modifier onlyOwner() {
        owner = msg.sender;
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    //function to create contract
    function createNftContract(
        uint256 _maxSupply,
        uint256 _maxAllowedMint,
        string memory _nftName,
        string memory _nftSymbol,
        string memory _initBaseURI
    ) public onlyOwner {
        nftCreate = new NftCollection(
            _maxSupply,
            _maxAllowedMint,
            _nftName,
            _nftSymbol,
            _initBaseURI
        );
        createdNftArray.push(nftCreate);
        createdAddress[_nftSymbol] = address(nftCreate);
    }

    //select the nftaddress for operations
    function chooseAddress(address _contractAddress) public {
        nftCreate = NftCollection(_contractAddress);
    }

    //set the coin
    function setAddCurrency(IERC20 _paytoken, uint256 _costvalue)
        public
        onlyOwner
    {
        nftCreate.addCurrency(_paytoken, _costvalue);
    }

    //set whitelist
    function setWhiteListedAddresses(
        address[] calldata addresses,
        uint256 numAllowedToMint
    ) public onlyOwner {
        nftCreate.setWhiteListedAddresses(addresses, numAllowedToMint);
    }

    //setBasetokenuri of the NFT
    function setNewBaseURI(string memory _newBaseURI) public onlyOwner {
        nftCreate.setBaseURI(_newBaseURI);
    }

    function setPause(bool _pause) public onlyOwner {
        nftCreate.setPaused(_pause);
    }

    function setAllowedMint(uint256 _newMint) public onlyOwner {
        nftCreate.setMaxAllowedMint(_newMint);
    }

    //check the address present or not
    function checkNftAddress(NftCollection _nftaddress)
        public
        view
        returns (bool status)
    {
        for (uint256 i = 0; i < createdNftArray.length; i++) {
            if (createdNftArray[i] == _nftaddress) {
                return true;
            }
        }
    }
}
