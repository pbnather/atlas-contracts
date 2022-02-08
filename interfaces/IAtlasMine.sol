// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

interface IAtlasMine {
    function treasure() external returns (address);

    function legion() external returns (address);

    function getStakedLegions(address _user) external view returns (uint256[] memory);

    function getUserBoost(address _user) external view returns (uint256);

    function getAllUserDepositIds(address _user) external view returns (uint256[] memory);

    function pendingRewardsPosition(address _user, uint256 _depositId) external view returns (uint256 pending);

    function pendingRewardsAll(address _user) external view returns (uint256 pending);

    enum Lock {
        twoWeeks,
        oneMonth,
        threeMonths,
        sixMonths,
        twelveMonths
    }

    function deposit(uint256 _amount, Lock _lock) external;

    function withdrawPosition(uint256 _depositId, uint256 _amount) external returns (bool);

    function withdrawAll() external;

    function harvestPosition(uint256 _depositId) external;

    function harvestAll() external;

    function withdrawAndHarvestPosition(uint256 _depositId, uint256 _amount) external;

    function withdrawAndHarvestAll() external;

    function stakeTreasure(uint256 _tokenId, uint256 _amount) external;

    function unstakeTreasure(uint256 _tokenId, uint256 _amount) external;

    function stakeLegion(uint256 _tokenId) external;

    function unstakeLegion(uint256 _tokenId) external;

    function getNftBoost(
        address _nft,
        uint256 _tokenId,
        uint256 _amount
    ) external view returns (uint256);
}
