// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface ICommunityMine {
    function harvestRewards() external returns (uint256 miningRewards, uint256 treasuryRewards);

    function getPendingRewards() external view returns (uint256);
}
