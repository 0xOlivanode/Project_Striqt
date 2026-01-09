// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
}

contract Striqt {
    IERC20 public immutable goodDollar;
    address public owner;

    uint256 private constant DAY = 1 days;

    struct Commitment {
        uint32 goalId;
        uint32 lastCheckInDay;
        uint16 streak;
        bool active;
    }

    struct Circle {
    uint32 goalId;
    address creator;
    mapping(address => bool) members;

    } 


    // user => commitment
    mapping(address => Commitment) public commitments;

    // user => milestone => claimed
    mapping(address => mapping(uint16 => bool)) public milestoneClaimed;

    // milestone days => reward amount
    mapping(uint16 => uint256) public milestoneReward;

    event Committed(address indexed user, uint32 goalId);
    event CheckedIn(address indexed user, uint16 streak);
    event RewardClaimed(address indexed user, uint16 milestone, uint256 amount);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    constructor(address _goodDollar) {
        owner = msg.sender;
        goodDollar = IERC20(_goodDollar);
    }

    // ----------------------------
    // Core Logic
    // ----------------------------

function commit(uint32 goalId) external {
    Commitment storage c = commitments[msg.sender];
    require(!c.active, "Active commitment exists");

    uint32 today = uint32(block.timestamp / DAY);

    commitments[msg.sender] = Commitment({
        goalId: goalId,
        lastCheckInDay: today,
        streak: 0,
        active: true
    });

    emit Committed(msg.sender, goalId);

    }

    function isValidCircleMember(address user, uint32 goalId) internal view returns (bool) {
    return commitments[user].active && commitments[user].goalId == goalId;
    
    }


function checkIn() external {
    Commitment storage c = commitments[msg.sender];
    require(c.active, "No active commitment");

    uint32 today = uint32(block.timestamp / DAY);
    require(today > c.lastCheckInDay, "Already checked in");

    if (today == c.lastCheckInDay + 1) {
        c.streak += 1;
    } else {
        c.streak = 1;
    }

    c.lastCheckInDay = today;
    emit CheckedIn(msg.sender, c.streak);
    
    }


    function claimReward(uint16 milestone) external {
        Commitment storage c = commitments[msg.sender];

        require(c.active, "No commitment");
        require(c.streak >= milestone, "Milestone not reached");
        require(!milestoneClaimed[msg.sender][milestone], "Already claimed");

        uint256 reward = milestoneReward[milestone];
        require(reward > 0, "Invalid milestone");

        milestoneClaimed[msg.sender][milestone] = true;
        require(goodDollar.transfer(msg.sender, reward), "Transfer failed");

        emit RewardClaimed(msg.sender, milestone, reward);
    }

    // ----------------------------
    // Admin
    // ----------------------------

    function setMilestone(uint16 daysCount, uint256 reward) external onlyOwner {
        milestoneReward[daysCount] = reward;
    }
}
