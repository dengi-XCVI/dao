// PSDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";

contract Box is Ownable {
    event NumberChanged(uint256 newNumber);

    uint256 private s_number;

    constructor() Ownable(msg.sender) {}

    function store(uint256 newNumber) public onlyOwner {
        s_number = newNumber;
        emit NumberChanged(newNumber);
    }

    function getNumber() public view returns (uint256) {
        return s_number;
    }

}