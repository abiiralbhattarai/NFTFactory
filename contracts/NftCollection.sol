//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract NftCollection is ERC721, Ownable {
    //For different token
    struct TokenInfo {
        IERC20 paytoken;
        uint256 costvalue;
    }

    TokenInfo[] public AllowedCrypto;

    using Strings for uint256;
    string public baseURI;
    string public baseExtension = ".json";
    bool public paused = false; //to pause the contract when needed
    bool public preSale = true;
    uint256 public maxSupply;
    uint256 public maxAllowedMint; //max number of mint allowed
    uint256 public preSaleTime;
    uint256 public totalSupplied;
    uint256 public preSaleEndTime;
    address[] public whiteListedAddresses;
    mapping(address => uint256) public addressMintedBalance;
    //setting the quantity allowed to mint by whitelist addresses
    mapping(address => uint256) public _allowedAddresses;

    constructor(
        uint256 _maxSupply,
        uint256 _maxAllowedMint,
        string memory _nftName,
        string memory _nftSymbol,
        string memory _initBaseURI
    ) ERC721(_nftName, _nftSymbol) {
        maxSupply = _maxSupply;
        maxAllowedMint = _maxAllowedMint;
        setBaseURI(_initBaseURI);
    }

    // internal function
    function _baseURI() internal view virtual override returns (string memory) {
        return baseURI;
    }

    //adding multiple tokens
    function addCurrency(IERC20 _paytoken, uint256 _costvalue)
        public
        onlyOwner
    {
        AllowedCrypto.push(
            TokenInfo({paytoken: _paytoken, costvalue: _costvalue})
        );
    }

    // mint function
    function mint(uint256 _mintAmount, uint256 _pid) public payable {
        TokenInfo storage tokens = AllowedCrypto[_pid];
        IERC20 paytoken;
        paytoken = tokens.paytoken;
        uint256 cost;
        cost = tokens.costvalue;
        uint256 tsupply = totalSupplied;
        require(!paused, "contract is paused");
        require(
            addressMintedBalance[msg.sender] <= maxAllowedMint,
            "Allowed Number Exceeded"
        );
        require(_mintAmount > 0, " Need to mint at least One NFT");
        require(tsupply + _mintAmount <= maxSupply, "NFT supply exceeded");
        if (preSale == true) {
            require(
                isWhitelisted(msg.sender) == true,
                "You are not whitelisted"
            );
            require(
                _mintAmount <= _allowedAddresses[msg.sender],
                "Allowed to mint Exceeded "
            );
        }
        if (msg.sender != owner()) {
            require(msg.value == cost * _mintAmount, "Not enough balance");
        }
        if (preSale == true && isWhitelisted(msg.sender) == true) {
            _allowedAddresses[msg.sender] -= _mintAmount;
        }

        for (uint256 i = 1; i <= _mintAmount; i++) {
            paytoken.transferFrom(msg.sender, address(this), cost);
            _safeMint(msg.sender, tsupply + i);
            addressMintedBalance[msg.sender]++;
            totalSupplied += i;
        }
    }

    //tokenURI function
    function tokenURI(uint256 tokenId)
        public
        view
        virtual
        override
        returns (string memory)
    {
        require(
            _exists(tokenId),
            "ERC721Metadata: URI query for nonexistent token"
        );

        string memory currentBaseURI = _baseURI();
        return
            bytes(currentBaseURI).length > 0
                ? string(
                    abi.encodePacked(
                        currentBaseURI,
                        tokenId.toString(),
                        baseExtension
                    )
                )
                : "";
    }

    //setting  whitelist addresses and number of token they can mint
    function setWhiteListedAddresses(
        address[] calldata addresses,
        uint256 numAllowedToMint
    ) public onlyOwner {
        for (uint256 i = 0; i < addresses.length; i++) {
            whiteListedAddresses.push(addresses[i]);
            _allowedAddresses[addresses[i]] = numAllowedToMint;
        }
    }

    //getWhiteListed Address and the number they can mint
    function getWhiteListedAddress()
        public
        view
        returns (address[] memory, uint256[] memory)
    {
        address[] memory addressAllowed = new address[](
            whiteListedAddresses.length
        );
        uint256[] memory mintAllowed = new uint256[](
            whiteListedAddresses.length
        );
        for (uint256 i = 0; i < whiteListedAddresses.length; i++) {
            addressAllowed[i] = whiteListedAddresses[i];
            mintAllowed[i] = _allowedAddresses[whiteListedAddresses[i]];
        }
        return (addressAllowed, mintAllowed);
    }

    //function to pause contract
    function setPaused(bool _state) public onlyOwner {
        paused = _state;
    }

    //function to set presale
    function setPreSale(bool _state) public onlyOwner {
        preSale = _state;
    }

    //function set presale time
    function setPreSaleTime(uint256 _numberofDays) public onlyOwner {
        preSaleTime = block.timestamp + _numberofDays * 1 days;
    }

    //set max allowed mint
    function setMaxAllowedMint(uint256 _allowedMint) public onlyOwner {
        maxAllowedMint = _allowedMint;
    }

    //settoken uri of the NFT
    function setBaseURI(string memory _newBaseURI) public onlyOwner {
        baseURI = _newBaseURI;
    }

    //check whitlisted address
    function isWhitelisted(address _user) public view returns (bool) {
        for (uint256 i = 0; i < whiteListedAddresses.length; i++) {
            if (whiteListedAddresses[i] == _user) {
                return true;
            }
        }
        return false;
    }

    //setthe baseextension
    function setBaseExtension(string memory _newBaseExtension)
        public
        onlyOwner
    {
        baseExtension = _newBaseExtension;
    }

    //function withdraw
    function withdraw(uint256 _pid) public payable onlyOwner {
        TokenInfo storage tokens = AllowedCrypto[_pid];
        IERC20 paytoken;
        paytoken = tokens.paytoken;
        paytoken.transfer(msg.sender, paytoken.balanceOf(address(this)));
    }
}
