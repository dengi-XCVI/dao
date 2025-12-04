// SPDX-License-Identifier: MIT

pragma solidity ^0.8.27;

import {Test, console} from "lib/forge-std/src/Test.sol";
import {MyGovernor} from "../src/Governor.sol";
import {MyToken} from "../src/GovToken.sol";
import {Box} from "../src/Box.sol";
import {TimeLock} from "../src/TimeLock.sol";

contract GovernorTest is Test {
    MyGovernor public governor;
    MyToken public token;
    Box public box;
    TimeLock public timelock;

    address public USER = makeAddr("user");
    uint256 public initialSupply = 100 ether;

    uint256 public constant MIN_DELAY = 3600; // 1 hour

    // Leave blank so that anybody can propose/execute
    address[] public proposers;
    address[] public executors;
    uint256[] public values;
    bytes[] public calldatas;
    address[] public targets;

    function setUp() public {
        token = new MyToken();
        token.mint(USER, initialSupply);
        vm.startPrank(USER);
        token.delegate(USER);
        timelock = new TimeLock(MIN_DELAY, proposers, executors);
        governor = new MyGovernor(token, timelock);
        bytes32 proposerRole = timelock.PROPOSER_ROLE();
        bytes32 executorRole = timelock.EXECUTOR_ROLE();
        bytes32 adminRole = timelock.DEFAULT_ADMIN_ROLE();

        timelock.grantRole(proposerRole, address(governor));
        timelock.grantRole(executorRole, address(0)); // anybody can execute past proposals
        timelock.revokeRole(adminRole, USER);
        vm.stopPrank();

        box = new Box();
        box.transferOwnership(address(timelock));
    }

    function testCantUpdateBoxWithoutGovernance() public {
        vm.prank(USER);
        vm.expectRevert();
        box.store(42);
    }

    function testGovernanceUpdatesBox() public {
        uint256 valueToStore = 888;
        string memory description = "Store 888 in the Box";
        bytes memory encodedFunctionCall = abi.encodeWithSignature("store(uint256)", valueToStore);
        values.push(0); 
        calldatas.push(encodedFunctionCall);
        targets.push(address(box));
        // propose to the dao
        uint256 proposalId = governor.propose(targets, values, calldatas, description);
        // view state
        console.log("Proposal state:", uint256(governor.state(proposalId))); // Should return 0 (Pending)
        vm.warp(block.timestamp + governor.votingDelay() + 1); // fast forward past voting delay
        vm.roll(block.number + governor.votingDelay() + 1); // fast forward past voting period
        console.log("Proposal state:", uint256(governor.state(proposalId))); 
        // cast vote
        string memory reason = "I like this proposal";  
        uint8 vote = 1; // 0 = Against, 1 = For, 2 = Abstain
        vm.prank(USER);
        governor.castVoteWithReason(proposalId, vote, reason);
        vm.warp(block.timestamp + governor.votingPeriod() + 1); // fast forward past voting delay
        vm.roll(block.number + governor.votingPeriod() + 1); // fast forward past voting delay

        // queue transaction
        bytes32 descriptionHash = keccak256(bytes(description));
        governor.queue(targets, values, calldatas, descriptionHash);

        // fast forward past timelock
        vm.warp(block.timestamp + MIN_DELAY + 1);
        vm.roll(block.number + MIN_DELAY + 1); // fast forward past voting period

        // execute proposal
        governor.execute(targets, values, calldatas, descriptionHash);

        assert(box.getNumber() == valueToStore);

    }
}