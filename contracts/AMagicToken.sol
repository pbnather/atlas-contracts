// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 *  @title AMagicToken
 *  @author pbnather
 *
 *  @notice This is simple ERC20 contract.
 *
 *  Only operator can mint or burn tokens.
 *  @dev Operator can be set only once.
 *
 *  It's a fork of linSpiritToken contract.
 */
contract AMagicToken is ERC20 {
    using SafeERC20 for IERC20;

    address public operator;
    address public owner;
    bool private _operatorSet;

    constructor() ERC20("aMAGIC", "Atlas Staked Magic") {
        operator = msg.sender;
        owner = msg.sender;
        _operatorSet = false;
    }

    function setOperator(address _operator) external {
        require(msg.sender == owner, "!auth");
        require(_operatorSet == false, "Operator was already set");
        _operatorSet = true;
        operator = _operator;
    }

    function mint(address _to, uint256 _amount) external {
        require(msg.sender == operator, "!authorized");

        _mint(_to, _amount);
    }

    function burn(address _from, uint256 _amount) external {
        require(msg.sender == operator, "!authorized");

        _burn(_from, _amount);
    }
}
