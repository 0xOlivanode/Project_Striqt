// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/Striqt.sol";
import "./mocks/MockGoodDollar.sol";

contract StriqtTest is Test {
    Striqt striqt;
    MockGoodDollar gdd;

    address owner = address(this);
    address user = address(0x1);

    uint16 constant MILESTONE_7 = 7;
    uint256 constant REWARD_7 = 5 ether;

    function setUp() public {
        gdd = new MockGoodDollar();
        striqt = new Striqt(address(gdd));

        // Fund contract with G$
        gdd.mint(address(striqt), 100 ether);

        // Set milestone
        striqt.setMilestone(MILESTONE_7, REWARD_7);
    }

    /* -------------------------- */
    /* Commit Tests               */
    /* -------------------------- */

    function testUserCanCommit() public {
        vm.prank(user);
        striqt.commit(1);

        (uint32 goalId,, uint16 streak, bool active) = striqt.commitments(user);

        assertEq(goalId, 1);
        assertEq(streak, 0);
        assertTrue(active);
    }

    function testCannotCommitTwice() public {
        vm.prank(user);
        striqt.commit(1);

        vm.prank(user);
        vm.expectRevert("Active commitment exists");
        striqt.commit(2);
    }

    /* -------------------------- */
    /* Check-In Tests             */
    /* -------------------------- */

    function testDailyCheckInIncreasesStreak() public {
        vm.prank(user);
        striqt.commit(1);

        vm.warp(block.timestamp + 1 days);

        vm.prank(user);
        striqt.checkIn();

        (, , uint16 streak,) = striqt.commitments(user);
        assertEq(streak, 1);
    }

    function testMissedDayResetsStreak() public {
        vm.prank(user);
        striqt.commit(1);

        vm.warp(block.timestamp + 1 days);
        vm.prank(user);
        striqt.checkIn();

        vm.warp(block.timestamp + 2 days);
        vm.prank(user);
        striqt.checkIn();

        (, , uint16 streak,) = striqt.commitments(user);
        assertEq(streak, 1);
    }

    function testCannotCheckInTwiceSameDay() public {
        vm.prank(user);
        striqt.commit(1);

        vm.warp(block.timestamp + 1 days);

        vm.prank(user);
        striqt.checkIn();

        vm.prank(user);
        vm.expectRevert("Already checked in");
        striqt.checkIn();
    }

    /* -------------------------- */
    /* Reward Tests               */
    /* -------------------------- */

    function testClaimRewardAfterMilestone() public {
        vm.prank(user);
        striqt.commit(1);

        for (uint256 i = 0; i < 7; i++) {
            vm.warp(block.timestamp + 1 days);
            vm.prank(user);
            striqt.checkIn();
        }

        uint256 balanceBefore = gdd.balanceOf(user);

        vm.prank(user);
        striqt.claimReward(MILESTONE_7);

        uint256 balanceAfter = gdd.balanceOf(user);

        assertEq(balanceAfter - balanceBefore, REWARD_7);
    }

    function testCannotClaimRewardTwice() public {
        vm.prank(user);
        striqt.commit(1);

        for (uint256 i = 0; i < 7; i++) {
            vm.warp(block.timestamp + 1 days);
            vm.prank(user);
            striqt.checkIn();
        }

        vm.prank(user);
        striqt.claimReward(MILESTONE_7);

        vm.prank(user);
        vm.expectRevert("Already claimed");
        striqt.claimReward(MILESTONE_7);
    }

    function testCannotClaimWithoutMilestone() public {
        vm.prank(user);
        striqt.commit(1);

        vm.warp(block.timestamp + 1 days);
        vm.prank(user);
        striqt.checkIn();

        vm.prank(user);
        vm.expectRevert("Milestone not reached");
        striqt.claimReward(MILESTONE_7);
    }
}