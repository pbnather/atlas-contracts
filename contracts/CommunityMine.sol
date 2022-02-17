// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/IERC1155Upgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "../interfaces/ICommunityMine.sol";
import "../interfaces/IAtlasMine.sol";
import "../interfaces/IAMagic.sol";

/**
 *  @title CommunityMine
 *  @author pbnather
 *
 *  @notice This contract allows users to stake MAGIC in AtlasMine for 1 year, coninously.
 *  By staking MAGIC users are minting aMAGIC tokens, liquid staked MAGIC. Then they can stake
 *  their aMAGIC, or provide aMAGIC-MAGIC LP tokens, and stake them in `aMagicStaking` contract,
 *  to get MAGIC rewards from AtlasMine.
 *
 *  Users can also stake their treasures/legions to boost the Community Mine.
 *  If all spots for NFTs are taken, users can replace these with lower boost.
 *  If multisig (`treasury`) has staked any NFT, it cannot be replaced.
 *  Part of rewards goes to `rewardSplitter` address.
 *
 *  Owner can upgrade the contract and change the parameters.
 *
 */
contract CommunityMine is Initializable, Ownable, ICommunityMine {
    using SafeERC20 for IERC20;
    using SafeERC20 for IAMagic;

    /// @notice Address of WETH token contract, for future Trove rewards.
    IERC20 public weth;

    /// @notice Address of MAGIC token contract.
    IERC20 public magic;

    /// @notice Address of aMAGIC token contract.
    IAMagic public aMagic;

    /// @notice Address of AtlasMine contract.
    IAtlasMine public atlasMine;

    /// @notice Address of MasterChef contract.
    address public aMagicStaking;

    /// @notice Address of the multisig/treasury.
    address public treasury;

    /// @notice Address of Treasure NFT collection.
    address public treasure;

    /// @notice Address of Legion NFT collection.
    address public legion;

    /// @notice Address of contract whihc splits rewards for team and treasury.
    address public rewardSplitter;

    /// @notice Percent of rewards that go to aMagicStaking (MasterChef) (1%=100).
    uint256 public miningPercent;

    /// @notice Current lock time
    IAtlasMine.Lock public lock;

    /// @notice Deposited MAGIC, not yet staked in Atlas Mine
    uint256 public idleMagic;

    /// @notice Threshold of deposited MAGIC to be staked in Atlas Mine.
    uint256 public depositThreshold;

    /**
     *  @notice Info of each staked NFT.
     */
    struct Staked {
        uint256 id; /// @notice Id of token in the NFT collection.
        uint256 boost; /// @notice Boost provided by NFT in Atlas Mine.
        address owner; /// @notice Owner of the  NFT.
    }

    /// @notice Array of all trasures staked in AtlasMine, max 20.
    Staked[] public stakedTreasures;

    /// @notice Array of all legions staked in AtlasMine, max 3.
    Staked[] public stakedLegions;

    event RewardSplitterChanged(address indexed oldAddress, address indexed newAddress);
    event MiningPercentChanged(uint256 indexed oldPercent, uint256 indexed newPercent);
    event RewardsHarvested(uint256 rewards, uint256 toStaking, uint256 toSplitter);
    event Deposit(address indexed user, uint256 amount);
    event StakedMagic(uint256 amount, IAtlasMine.Lock indexed lock);
    event StakedTreasure(address indexed owner, uint256 indexed tokenId);
    event UnstakedTreasure(address indexed owner, uint256 indexed tokenId);
    event StakedLegion(address indexed owner, uint256 indexed tokenId);
    event UnstakedLegion(address indexed owner, uint256 indexed tokenId);
    event LockTimeChanged(IAtlasMine.Lock oldLock, IAtlasMine.Lock newLock);
    event DepositThresholdChanged(uint256 oldThreshold, uint256 newThreshold);

    function initialize(
        address _weth,
        address _magic,
        address _aMagic,
        address _atlasMine,
        address _aMagicStaking,
        address _treasury,
        address _rewardSplitter,
        uint256 _miningPercent,
        uint256 _depositThreshold,
        IAtlasMine.Lock _lock
    ) external initializer {
        require(_weth != address(0), "Cannot set address zero");
        weth = IERC20(_weth);
        require(_magic != address(0), "Cannot set address zero");
        magic = IERC20(_magic);
        require(_aMagic != address(0), "Cannot set address zero");
        aMagic = IAMagic(_aMagic);
        require(_atlasMine != address(0), "Cannot set address zero");
        atlasMine = IAtlasMine(_atlasMine);
        require(_aMagicStaking != address(0), "Cannot set address zero");
        aMagicStaking = _aMagicStaking;
        require(_treasury != address(0), "Cannot set address zero");
        treasury = _treasury;
        require(_rewardSplitter != address(0), "Cannot set address zero");
        rewardSplitter = _rewardSplitter;
        require(_miningPercent <= 10_000, "Value greater than 1000, 100%");
        miningPercent = _miningPercent;
        lock = _lock;
        idleMagic = 0;
        depositThreshold = _depositThreshold;
        // Get Legion and Treasure addresses
        treasure = atlasMine.treasure();
        legion = atlasMine.legion();
        // Approve Legion and Treasure conllections
        IERC1155Upgradeable(treasure).setApprovalForAll(_atlasMine, true);
        IERC721Upgradeable(legion).setApprovalForAll(_atlasMine, true);
    }

    /**
     *  @notice Set new address for `rewardSplitter`.
     *  @param _rewardSplitter Address of the new splitter.
     */
    function setRewardSplitter(address _rewardSplitter) external onlyOwner {
        require(_rewardSplitter != address(0), "Cannot set address zero");
        address old = rewardSplitter;
        rewardSplitter = _rewardSplitter;
        emit RewardSplitterChanged(old, _rewardSplitter);
    }

    /**
     *  @notice Set new `miningPercent`, how much % of rewards will get distributed to stakers.
     *  @dev How much % of rewards will get sent to MasterChef (`aMagicStaking`).
     *  @param _miningPercent Mining percent, max 100% (10000).
     */
    function setMiningPercent(uint256 _miningPercent) external onlyOwner {
        require(_miningPercent <= 10_000, "Value greater than 10000, 100%");
        uint256 old = miningPercent;
        miningPercent = _miningPercent;
        emit MiningPercentChanged(old, _miningPercent);
    }

    /**
     *  @notice Set new `lock`, time for which to stake/restake magic in Atlas Mine.
     *  @param _lock New locktime period.
     */
    function changeLockTime(IAtlasMine.Lock _lock) external onlyOwner {
        IAtlasMine.Lock old = lock;
        lock = _lock;
        emit LockTimeChanged(old, _lock);
    }

    /**
     *  @notice Set new `depositThreshold`, minimum MAGIC to be staked in Atlas Mine.
     *  @param _depositThreshold New deposit threshold.
     */
    function changeDepositThreshold(uint256 _depositThreshold) external onlyOwner {
        uint256 old = depositThreshold;
        depositThreshold = _depositThreshold;
        emit DepositThresholdChanged(old, _depositThreshold);
    }

    /**
     *  @notice Withdraw deposits and restake them in the Atlas Mine.
     *  @param _depositIds List of deposits to withdraw and restake.
     */
    function restakeMagic(uint256[] memory _depositIds) external {
        require(msg.sender == treasury, "Only treasury allowed");
        for (uint256 i = 0; i < _depositIds.length; i++) {
            atlasMine.withdrawPosition(_depositIds[i], type(uint256).max);
        }
        uint256 magicBalance = magic.balanceOf(msg.sender);
        magic.approve(address(atlasMine), magicBalance);
        atlasMine.deposit(magicBalance, lock);
        emit StakedMagic(magicBalance, lock);
    }

    /**
     *  @notice Deposit MAGIC to Atlas Mine, mint aMAGIC 1:1 for MAGIC deposited.
     *  @param _amount Amount of MAGIC to convert to aMAGIC.
     */
    function deposit(uint256 _amount) external {
        require(_amount <= magic.balanceOf(msg.sender), "Not enough MAGIC");
        magic.safeTransferFrom(msg.sender, address(this), _amount);
        uint256 magicToStake = _amount + idleMagic;
        if (magicToStake >= depositThreshold) {
            idleMagic = 0;
            magic.approve(address(atlasMine), magicToStake);
            atlasMine.deposit(magicToStake, lock);
            emit StakedMagic(magicToStake, lock);
        } else {
            idleMagic = magicToStake;
        }
        aMagic.mint(msg.sender, _amount);
        emit Deposit(msg.sender, _amount);
    }

    /**
     *  @notice Stake single Treasure NFT into the Community Mine to boost MAGIC rewards.
     *  If all treasure slots are full, this function will replace Treasure with the lowest boost,
     *  if it's lower than provided one, and send it back to the owner. If no such a treasure exists,
     *  or existing one is controlled by `treasury`, contract execution will revert.

     *  @param _tokenId Id of the token in the Treasure NFT Collection.
     */
    function stakeSingleTreasure(uint256 _tokenId) external {
        uint256 boost = atlasMine.getNftBoost(treasure, _tokenId, 1);
        require(boost != 0, "error calcualting boost");
        if (stakedTreasures.length < 20) {
            stakedTreasures.push(Staked({id: _tokenId, boost: boost, owner: msg.sender}));
        } else {
            uint256 minimalBoostIndex = 20;
            uint256 minimalBoost = boost;
            for (uint256 i = 0; i < 20; i++) {
                if (stakedTreasures[i].boost < minimalBoost && stakedTreasures[i].owner != treasury) {
                    minimalBoost = stakedTreasures[i].boost;
                    minimalBoostIndex = i;
                }
            }
            require(minimalBoostIndex < 20, "No treasure to replace found");
            // Send NFT back to the owner
            atlasMine.unstakeTreasure(stakedTreasures[minimalBoostIndex].id, 1);
            IERC1155Upgradeable(treasure).safeTransferFrom(
                address(this),
                stakedTreasures[minimalBoostIndex].owner,
                stakedTreasures[minimalBoostIndex].id,
                1,
                bytes("")
            );
            emit UnstakedTreasure(stakedTreasures[minimalBoostIndex].owner, stakedTreasures[minimalBoostIndex].id);

            stakedTreasures[minimalBoostIndex] = Staked({id: _tokenId, boost: boost, owner: msg.sender});
        }

        // Send NFT to CommunityMine and stake in Atlas Mine
        IERC1155Upgradeable(treasure).safeTransferFrom(msg.sender, address(this), _tokenId, 1, bytes(""));
        atlasMine.stakeTreasure(_tokenId, 1);
        emit StakedTreasure(msg.sender, _tokenId);
    }

    /**
     *  @notice Withdraw single Treasure NFT. Only owner can withdraw.
     *  @param _index Index of NFT to withdraw in `stakedTreasures` array.
     */
    function withdrawSingleTreasure(uint256 _index) external {
        require(stakedTreasures[_index].owner == msg.sender, "Only owner can withdraw");
        atlasMine.unstakeTreasure(stakedTreasures[_index].id, 1);
        IERC1155Upgradeable(treasure).safeTransferFrom(
            address(this),
            stakedTreasures[_index].owner,
            stakedTreasures[_index].id,
            1,
            bytes("")
        );
        emit UnstakedTreasure(stakedTreasures[_index].owner, stakedTreasures[_index].id);
        stakedTreasures[_index] = stakedTreasures[stakedTreasures.length - 1];
        stakedTreasures.pop();
    }

    /**
     *  @notice Stake single Legion NFT into the Community Mine to boost MAGIC rewards.
     *  If all legion slots are full, this function will replace Legion with the lowest boost,
     *  if it's lower than provided one, and send it back to the owner. If no such a legion exists,
     *  or existing one is controlled by `treasury`, contract execution will revert.
     *
     *  @param _tokenId Id of the token in the Legion NFT Collection.
     */
    function stakeSingleLegion(uint256 _tokenId) external {
        uint256 boost = atlasMine.getNftBoost(legion, _tokenId, 1);
        require(boost != 0, "error calcualting boost");
        if (stakedLegions.length < 3) {
            stakedLegions.push(Staked({id: _tokenId, boost: boost, owner: msg.sender}));
        } else {
            uint256 minimalBoostIndex = 3;
            uint256 minimalBoost = boost;
            for (uint256 i = 0; i < 3; i++) {
                if (stakedLegions[i].boost < minimalBoost && stakedLegions[i].owner != treasury) {
                    minimalBoost = stakedLegions[i].boost;
                    minimalBoostIndex = i;
                }
            }
            require(minimalBoostIndex < 3, "No legion to replace found");
            // Send NFT back to the owner
            atlasMine.unstakeLegion(stakedLegions[minimalBoostIndex].id);
            IERC721Upgradeable(legion).transferFrom(
                address(this),
                stakedLegions[minimalBoostIndex].owner,
                stakedLegions[minimalBoostIndex].id
            );

            emit UnstakedLegion(stakedLegions[minimalBoostIndex].owner, stakedLegions[minimalBoostIndex].id);

            stakedLegions[minimalBoostIndex] = Staked({id: _tokenId, boost: boost, owner: msg.sender});
        }

        // Send NFT to CommunityMine and stake in Atlas Mine
        IERC721Upgradeable(legion).transferFrom(msg.sender, address(this), _tokenId);
        atlasMine.stakeLegion(_tokenId);
        emit StakedLegion(msg.sender, _tokenId);
    }

    /**
     *  @notice Withdraw single Legion NFT. Only owner can withdraw.
     *  @param _index Index of NFT to withdraw in `stakedLegions` array.
     */
    function withdrawSingleLegion(uint256 _index) external {
        require(stakedLegions[_index].owner == msg.sender, "Only owner can withdraw");
        atlasMine.unstakeLegion(stakedLegions[_index].id);
        IERC721Upgradeable(legion).transferFrom(address(this), stakedLegions[_index].owner, stakedLegions[_index].id);

        emit UnstakedLegion(stakedLegions[_index].owner, stakedLegions[_index].id);

        stakedLegions[_index] = stakedLegions[stakedLegions.length - 1];
        stakedLegions.pop();
    }

    /**
     *  @notice Harvest rewards from Atlas Mine and send:
     *   - `miningPercent` rewards to `aMagicStaking` contract.
     *   - (100% - `miningPercent`) rewards to `rewardSplitter` contract.
     *
     *  NOTE Can only be called by `aMagicStaking` contract.
     */
    function harvestRewards() external override returns (uint256 miningRewards, uint256 treasuryRewards) {
        require(msg.sender == aMagicStaking, "Only aMagicStaking allowed");
        atlasMine.harvestAll();
        uint256 harvestedMagic = magic.balanceOf(address(this)) - idleMagic;
        miningRewards = (harvestedMagic * miningPercent) / 10_000;
        treasuryRewards = harvestedMagic - miningRewards;
        magic.safeTransfer(aMagicStaking, miningRewards);
        magic.safeTransfer(rewardSplitter, treasuryRewards);
        emit RewardsHarvested(harvestedMagic, miningRewards, treasuryRewards);
    }

    /**
     *  @return pending MAGIC rewards from Atlas Mine.
     */
    function getPendingRewards() external view override returns (uint256 pending) {
        pending = atlasMine.pendingRewardsAll(address(this));
    }

    /**
     *  @return boost current Community Mine boost in Atlas Mine.
     */
    function getBoost() external view returns (uint256 boost) {
        boost = atlasMine.getUserBoost(address(this));
    }

    /**
     *  @return length of `stakedTreasures` array.
     */
    function getTreasuresLength() external view returns (uint256 length) {
        length = stakedTreasures.length;
    }

    /**
     *  @return length of `stakedLegions` array.
     */
    function getLegionsLength() external view returns (uint256 length) {
        length = stakedLegions.length;
    }

    /**
     *  @notice Allow anyone to send lost tokens to the owner, except MAGIC token.
     *  @return bool
     */
    function recoverLostToken(IERC20 _token) external returns (bool) {
        require(address(_token) != address(magic), "Cannot recover MAGIC");
        uint256 balance = _token.balanceOf(address(this));
        _token.safeTransfer(owner(), balance);
        return true;
    }
}
