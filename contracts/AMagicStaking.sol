// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../interfaces/IAMagic.sol";
import "../interfaces/ICommunityMine.sol";
import "../interfaces/IRewarder.sol";

/**
 *  @title AMagicStaking
 *  @author pbnather
 *  @notice This contract is a fork of SushiSwap's MasterChefV2 - however it has some differences.
 *
 *  - It was upgraded to solidity 0.8.11.
 *  - Rewards are not distributed per block, but on every `massUpdatePools()` function call,
 *    which harvests MAGIC rewards from the community mine, as actual `Chef` is Atlas Mine,
 *    interacted with via CommunityMine contract.
 *
 *  Note that it's ownable and the owner wields a tremendous power.
 */
contract AMagicStaking is Ownable {
    using SafeERC20 for IERC20;

    /**
     *  @notice Info of each MCV2 user.
     *  `amount` LP token amount the user has provided.
     *  `rewardDebt` The amount of SUSHI entitled to the user.
     */
    struct UserInfo {
        uint256 amount;
        uint256 rewardDebt;
    }

    /**
     *  @notice Info of each MCV2 pool.
     */
    struct PoolInfo {
        uint256 allocPoint; // How many allocation points assigned to this pool.
        uint256 accMagicPerShare; // Accumulated MAGIC per share, times 1e12. See below.
    }

    /// @notice Address of MAGIC contract.
    IERC20 public immutable magic;

    /// @notice Address of the CommunityMine contract.
    ICommunityMine public immutable communityMine;

    /// @notice Info of each MCV2 pool.
    PoolInfo[] public poolInfo;

    /// @notice Address of the LP token for each MCV2 pool.
    IERC20[] public lpToken;

    /// @notice Address of each `IRewarder` contract in MCV2.
    IRewarder[] public rewarder;

    /// @notice Info of each user that stakes LP tokens.
    mapping(uint256 => mapping(address => UserInfo)) public userInfo;

    /// @dev Tokens added
    mapping(address => bool) public addedTokens;

    /// @dev Total allocation points. Must be the sum of all allocation points in all pools.
    uint256 public totalAllocPoint;

    /// @dev Last block when rewards for all pools were updated.
    uint256 public lastRewardBlock;

    uint256 private constant ACC_PRECISION = 1e12;

    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event Harvest(address indexed user, uint256 indexed pid, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event LogPoolAddition(uint256 indexed pid, uint256 allocPoint, IERC20 indexed lpToken, IRewarder indexed rewarder);
    event LogSetPool(uint256 indexed pid, uint256 allocPoint, IRewarder indexed rewarder, bool overwrite);
    event LogUpdatePool(uint256 indexed pid, uint256 lastRewardTime, uint256 lpSupply);

    /**
     *  @param _magic The MAGIC token contract address.
     *  @param _communityMine The CommunityMine contract address.
     */
    constructor(address _magic, address _communityMine) {
        require(_magic != address(0), "Canot set address zero");
        magic = IERC20(_magic);
        require(_communityMine != address(0), "Canot set address zero");
        communityMine = ICommunityMine(_communityMine);
        lastRewardBlock = block.number;
    }

    modifier updatePools() {
        massUpdatePools();
        _;
    }

    /// @notice Returns the number of MCV2 pools.
    function poolLength() external view returns (uint256 pools) {
        pools = poolInfo.length;
    }

    /**
     *  @notice Add a new LP to the pool. Can only be called by the owner.
     *  @param _allocPoint AP of the new pool.
     *  @param _lpToken Address of the LP ERC-20 token.
     *  @param _rewarder Address of the rewarder delegate.
     */
    function add(
        uint256 _allocPoint,
        IERC20 _lpToken,
        IRewarder _rewarder
    ) external onlyOwner updatePools {
        require(addedTokens[address(_lpToken)] == false, "Token already added");

        addedTokens[address(_lpToken)] = true;
        totalAllocPoint += _allocPoint;
        lpToken.push(_lpToken);
        rewarder.push(_rewarder);
        poolInfo.push(PoolInfo({allocPoint: _allocPoint, accMagicPerShare: 0}));

        emit LogPoolAddition(lpToken.length - 1, _allocPoint, _lpToken, _rewarder);
    }

    /**
     *  @notice Update the given pool's MAGIC allocation point and `IRewarder` contract. Can only be called by the owner.
     *  @param _pid The index of the pool. See `poolInfo`.
     *  @param _allocPoint New AP of the pool.
     *  @param _rewarder Address of the rewarder delegate.
     *  @param _overwrite True if _rewarder should be `set`. Otherwise `_rewarder` is ignored.
     */
    function set(
        uint256 _pid,
        uint256 _allocPoint,
        IRewarder _rewarder,
        bool _overwrite
    ) external onlyOwner updatePools {
        totalAllocPoint += _allocPoint - poolInfo[_pid].allocPoint;
        poolInfo[_pid].allocPoint = _allocPoint;

        if (_overwrite) {
            rewarder[_pid] = _rewarder;
        }

        emit LogSetPool(_pid, _allocPoint, _overwrite ? _rewarder : rewarder[_pid], _overwrite);
    }

    /**
     *  @notice View function to see pending MAGIC on frontend.
     *  @param _pid The index of the pool. See `poolInfo`.
     *  @param _user Address of user.
     *  @return pending MAGIC reward for a given user.
     */
    function pendingMagic(uint256 _pid, address _user) external view returns (uint256 pending) {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint256 accMagicPerShare = pool.accMagicPerShare;
        uint256 lpSupply = lpToken[_pid].balanceOf(address(this));
        if (block.number > lastRewardBlock && lpSupply != 0) {
            uint256 reward = communityMine.getPendingRewards();
            uint256 poolReward = (reward * pool.allocPoint) / totalAllocPoint;
            accMagicPerShare += ((poolReward * ACC_PRECISION) / lpSupply);
        }
        pending = ((user.amount * accMagicPerShare) / ACC_PRECISION) - user.rewardDebt;
    }

    /**
     *  @notice Update reward variables for all pools. Be careful of gas spending!
     *  Before updating harvests rewards from the community mine.
     */
    function massUpdatePools() public {
        if (lastRewardBlock < block.number) {
            (uint256 reward, ) = communityMine.harvestRewards();
            uint256 length = poolInfo.length;
            for (uint256 pid = 0; pid < length; ++pid) {
                _updatePool(pid, reward);
            }
            lastRewardBlock = block.number;
        }
    }

    /**
     *  @notice Update reward variables of the given pool.
     *  @param _pid The index of the pool. See `poolInfo`.
     *  @param _reward Current harvested reward.
     */
    function _updatePool(uint256 _pid, uint256 _reward) internal {
        PoolInfo storage pool = poolInfo[_pid];
        uint256 lpSupply = lpToken[_pid].balanceOf(address(this));
        if (lpSupply == 0) return;
        uint256 poolReward = (_reward * pool.allocPoint) / totalAllocPoint;
        pool.accMagicPerShare += (poolReward * ACC_PRECISION) / lpSupply;
        emit LogUpdatePool(_pid, lastRewardBlock, lpSupply);
    }

    /**
     *  @notice Deposit LP tokens to MCV2 for MAGIC allocation.
     *  @param _pid The index of the pool. See `poolInfo`.
     *  @param _amount LP token amount to deposit.
     */
    function deposit(uint256 _pid, uint256 _amount) external updatePools {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        uint256 pending = 0;
        if (user.amount > 0) {
            pending = ((user.amount * pool.accMagicPerShare) / ACC_PRECISION) - user.rewardDebt;
        }

        // Effects
        user.amount += _amount;
        user.rewardDebt = (user.amount * pool.accMagicPerShare) / ACC_PRECISION;

        // Interactions
        _harvest(pending, user.amount - _amount, _pid);
        lpToken[_pid].safeTransferFrom(msg.sender, address(this), _amount);
        emit Deposit(msg.sender, _pid, _amount);
    }

    /**
     *  @notice Withdraw LP tokens from MCV2.
     *  @param _pid The index of the pool. See `poolInfo`.
     *  @param _amount LP token amount to withdraw.
     */
    function withdraw(uint256 _pid, uint256 _amount) external updatePools {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        require(user.amount >= _amount, "Not enough tokens");
        uint256 pending = ((user.amount * pool.accMagicPerShare) / ACC_PRECISION) - user.rewardDebt;

        // Effects
        user.amount -= _amount;
        user.rewardDebt = (user.amount * pool.accMagicPerShare) / ACC_PRECISION;

        // Interactions
        _harvest(pending, user.amount + _amount, _pid);
        lpToken[_pid].safeTransfer(msg.sender, _amount);
        emit Withdraw(msg.sender, _pid, _amount);
    }

    /**
     *  @notice Harvest IRewarder and MAGIC rewards.
     *  @param _pid The index of the pool. See `poolInfo`.
     */
    function harvest(uint256 _pid) external updatePools {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        if (user.amount == 0) return;
        uint256 pending = ((user.amount * pool.accMagicPerShare) / ACC_PRECISION) - user.rewardDebt;

        // Effects
        user.rewardDebt = (user.amount * pool.accMagicPerShare) / ACC_PRECISION;

        //Interactions
        _harvest(pending, user.amount, _pid);
    }

    /**
     *  @notice Harvest IRewarder and MAGIC rewards. Internal function.
     *  @param _pendingMagic Amount of MAGIC rewards to payout.
     *  @param _userAmount Amount of user tokens in the pool before deposit/withdraw.
     *  @param _pid The index of the pool. See `poolInfo`.
     */
    function _harvest(
        uint256 _pendingMagic,
        uint256 _userAmount,
        uint256 _pid
    ) internal {
        IRewarder _rewarder = rewarder[_pid];
        if (address(_rewarder) != address(0)) {
            _rewarder.onMagicReward(_pid, msg.sender, msg.sender, 0, _userAmount);
        }

        if (_pendingMagic > 0) {
            _safeMagicTransfer(msg.sender, _pendingMagic);
            emit Harvest(msg.sender, _pid, _pendingMagic);
        }
    }

    /**
     *  @notice Withdraw without caring about rewards. EMERGENCY ONLY.
     *  @param _pid The index of the pool. See `poolInfo`.
     */
    function emergencyWithdraw(uint256 _pid) external {
        UserInfo storage user = userInfo[_pid][msg.sender];
        lpToken[_pid].safeTransfer(msg.sender, user.amount);
        user.amount = 0;
        user.rewardDebt = 0;
        emit EmergencyWithdraw(msg.sender, _pid, user.amount);
    }

    /**
     *  @notice Safe MAGIC transfer function, just in case if rounding error causes pool to not have enough MAGIC.
     *  @param _to Address to which to send MAGIC.
     *  @param _amount Amount of MAGIC to send.
     */
    function _safeMagicTransfer(address _to, uint256 _amount) internal {
        uint256 magicBalance = magic.balanceOf(address(this));
        if (_amount > magicBalance) {
            magic.safeTransfer(_to, magicBalance);
        } else {
            magic.safeTransfer(_to, _amount);
        }
    }
}
