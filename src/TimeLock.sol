// SPDX-License-Identifier: MIT

pragma solidity ^0.8.27;

import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";

contract TimeLock is TimelockController {
    constructor(
        uint256 minDelay, // How long you have to wait before executing
        address[] memory proposers, // List of addresses can propose
        address[] memory executors // List of addresses can execute
    ) TimelockController(minDelay, proposers, executors, msg.sender) {}
}