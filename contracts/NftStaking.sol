//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

import "./NftCollection.sol";
import "./AbiToken.sol";
import "./NftFactory.sol";

contract NftStaking is Ownable, ReentrancyGuard, IERC721Receiver {
    //details of the nfts and token used in staking
    struct vaultDetails {
        NftCollection nft;
        FuelToken rewardToken;
        string name;
        uint256 rewardPerhour;
        uint256 stakingTime;
    }

    vaultDetails[] public vaultArray;

    //staking information
    struct Stake {
        uint256 tokenId;
        uint256 timestamp;
        address owner;
    }

    //about the rewards given to the stakers
    struct rewardDetails {
        uint256 lastReward; //latest reward withdrawn
        uint256 totalRewardsEarned; //total rewards
        uint256 unclaimedRewards; //reward remained to claim
        uint256 timeOfLastUpdate; //last time the rewards were calculated
    }

    uint256 public totalStaked;
    uint256 public stakingStartTime;
    bool public tokensClaimable;
    bool initialised;
    mapping(uint256 => Stake) public vault;
    mapping(address => mapping(uint256 => rewardDetails)) public stakerRewards;
    mapping(NftCollection => uint256) public nftVaultDetails;//to get the vaultDetails by passing the nft address

    /// @notice event emitted when a user has staked a token
    event NftStaked(address indexed owner, uint256 tokenId, uint256 value);

    /// @notice event emitted when a user has unstaked a token
    event NftUnstaked(address indexed owner, uint256 tokenId, uint256 value);

    /// @notice event emitted when a user claims reward
    event Claimed(address indexed owner, uint256 amount);

    /// @notice Allows reward tokens to be claimed
    event ClaimableStatusUpdated(bool status);

    //reference to the contracts
    NftCollection nftToStake;
    FuelToken tokenToReward;
    NftFactory nftFactory;
    
//function to add details
    function addInVault(
        NftCollection _nft,
        FuelToken _token,
        string memory _name,
        uint256 _rewardPerhour,
        uint256 _stakingTime
    ) public onlyOwner {
      uint256 vaultCounter;
        require(
            nftFactory.checkNftAddress(_nft) == true,
            "Not a Fuel Factory Nft address"
        );
        vaultArray.push(
            vaultDetails({
                nft: _nft,
                rewardToken: _token,
                name: _name,
                rewardPerhour: _rewardPerhour,
                stakingTime: _stakingTime
            })
        );
        nftVaultDetails[_nft] = vaultCounter;
        vaultCounter +=1;
    }
constructor() {}
    function initStaking() public onlyOwner {
        //needs access control
        require(!initialised, "Already initialised");
        stakingStartTime = block.timestamp;
        initialised = true;
    }

    function setTokensClaimable(bool _enabled) public onlyOwner {
        //needs access control
        tokensClaimable = _enabled;
        emit ClaimableStatusUpdated(_enabled);
    }

    //function to stake the available NFT
    function stakeNft(uint256 _vId, uint256[] calldata _tokenIds) public {
        uint256 tokenId;
        require(initialised, "Staking System has not started");
        totalStaked += _tokenIds.length;
        if (stakedAmount(msg.sender, _vId) > 0) {
            uint256 rewards = calculateRewards(msg.sender, _vId);
            stakerRewards[msg.sender][_vId].unclaimedRewards += rewards;
            stakerRewards[msg.sender][_vId].totalRewardsEarned += rewards;
            stakerRewards[msg.sender][_vId].timeOfLastUpdate = block.timestamp;
        }
        vaultDetails storage vaultId = vaultArray[_vId];
        for (uint256 i = 0; i < _tokenIds.length; i++) {
            tokenId = _tokenIds[i];
            require(
                vaultId.nft.ownerOf(tokenId) == msg.sender,
                "not your token"
            );
            require(vault[tokenId].tokenId == 0, "already staked"); //to check already staked or not
            vaultId.nft.transferFrom(msg.sender, address(this), tokenId);
            emit NftStaked(msg.sender, tokenId, block.timestamp);
            vault[tokenId] = Stake(tokenId, block.timestamp, msg.sender);
        }
    }

    //claiming only the reward
    function claimOnlyReward(
        address _staker,
        uint256[] calldata tokenIds,
        uint256 _vId
    ) external {
        require(stakedAmount(_staker, _vId) > 0, "You have no token staked");
        _claimMain(_staker, tokenIds, _vId, false);
    }

    //claim all reward and NFT
    function unstakeNft(
        address _staker,
        uint256[] calldata tokenIds,
        uint256 _vId
    ) public {
        require(stakedAmount(_staker, _vId) > 0, "You have no token staked");
        _claimMain(_staker, tokenIds, _vId, true);
    }

    //main unstake function
    function unstake(
        address _user,
        uint256[] calldata _tokenIds,
        uint256 _vId
    ) internal {
        uint256 tokenId;
        totalStaked -= _tokenIds.length;
        vaultDetails storage vaultId = vaultArray[_vId];
        for (uint256 i = 0; i < _tokenIds.length; i++) {
            tokenId = _tokenIds[i];
            Stake memory staked = vault[tokenId];
            require(staked.owner == _user, "not an owner");
            vaultId.nft.transferFrom(address(this), _user, tokenId);
            delete vault[tokenId];
            emit NftUnstaked(_user, tokenId, block.timestamp);
        }
    }

    //get all the nft staked
    function getStakedNft(address _account, uint256 _vId)
        public
        view
        returns (uint256[] memory ownerTokens)
    {
        vaultDetails storage vaultId = vaultArray[_vId];
        uint256 supply = vaultId.nft.totalSupplied();
        uint256[] memory tmp = new uint256[](supply);

        uint256 index = 0;
        for (uint256 tId = 1; tId <= supply; tId++) {
            if (vault[tId].owner == _account) {
                tmp[index] = vault[tId].tokenId;
                index += 1;
            }
        }

        uint256[] memory tokens = new uint256[](index);
        for (uint256 i = 0; i < index; i++) {
            tokens[i] = tmp[i];
        }

        return tokens;
    }

    //get the total amount of nft staked
    function stakedAmount(address account, uint256 _vId)
        public
        view
        returns (uint256)
    {
        uint256 nftStaked;
        vaultDetails storage vaultId = vaultArray[_vId];
        uint256 supply = vaultId.nft.totalSupplied();
        for (uint256 i = 1; i <= supply; i++) {
            if (vault[i].owner == account) {
                nftStaked += 1;
            }
        }
        return nftStaked;
    }

    //main claim function
    function _claimMain(
        address _staker,
        uint256[] calldata tokenIds,
        uint256 _vId,
        bool _unstake
    ) internal {
        vaultDetails storage vaultId = vaultArray[_vId];
        uint256 rewards = calculateRewards(_staker, _vId);
        stakerRewards[_staker][_vId].unclaimedRewards += rewards;
        stakerRewards[_staker][_vId].totalRewardsEarned += rewards;
        uint256 unclaimedReward = stakerRewards[_staker][_vId].unclaimedRewards;
        require(unclaimedReward > 0, "You have no rewards to claim");
        stakerRewards[_staker][_vId].timeOfLastUpdate = block.timestamp;
        if (unclaimedReward > 0) {
            vaultId.rewardToken.mint(_staker, unclaimedReward);
            stakerRewards[_staker][_vId].unclaimedRewards = 0;
        }
        if (_unstake) {
            unstake(_staker, tokenIds, _vId);
        }
        emit Claimed(_staker, unclaimedReward);
    }

    //calculation of rewards
    function calculateRewards(address _staker, uint256 _vId)
        internal
        view
        returns (uint256 _rewards)
    {
        vaultDetails storage vaultId = vaultArray[_vId];
        return (((
            ((block.timestamp - stakerRewards[_staker][_vId].timeOfLastUpdate) *
                stakedAmount(_staker, _vId))
        ) * vaultId.rewardPerhour) / vaultId.stakingTime);
    }

    //available rewards that can be claimed
    function availableRewards(address _staker, uint256 _vId)
        public
        returns (uint256)
    {
        require(stakedAmount(_staker, _vId) > 0, "You have no token staked");
        uint256 rewards = calculateRewards(_staker, _vId);
        stakerRewards[_staker][_vId].unclaimedRewards += rewards;
        stakerRewards[_staker][_vId].totalRewardsEarned += rewards;
        stakerRewards[_staker][_vId].timeOfLastUpdate = block.timestamp;
        return (stakerRewards[_staker][_vId].unclaimedRewards);
    }

    //Earning till now
    function totalEarnedRewards(address _staker, uint256 _vId)
        public
        returns (uint256)
    {
        require(stakedAmount(_staker, _vId) > 0, "You have no token staked");
        uint256 rewards = calculateRewards(_staker, _vId);
        stakerRewards[_staker][_vId].unclaimedRewards += rewards;
        stakerRewards[_staker][_vId].totalRewardsEarned += rewards;
        stakerRewards[_staker][_vId].timeOfLastUpdate = block.timestamp;
        return (stakerRewards[_staker][_vId].totalRewardsEarned);
    }

    //function to updateReward of NFT
    function updateRewardPerhour(uint256 _vId, uint256 _rewardPerhour)
        public
        onlyOwner
    {
        vaultDetails storage vaultId = vaultArray[_vId];
        vaultId.rewardPerhour = _rewardPerhour;
    }

    //function to updateReward of NFT
    function updateStakingTime(uint256 _vId, uint256 _stakingTime)
        public
        onlyOwner
    {
        vaultDetails storage vaultId = vaultArray[_vId];
        vaultId.stakingTime = _stakingTime;
    }

    function onERC721Received(
        address,
        address from,
        uint256,
        bytes calldata
    ) external pure override returns (bytes4) {
        require(from == address(0x0), "Cannot send nfts to Vault directly");
        return IERC721Receiver.onERC721Received.selector;
    }
}
