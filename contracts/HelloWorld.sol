// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";

contract HelloWorld is Ownable {
    function sayHello() external pure returns (string memory) {
        return "hello world";
    }
}
