pragma solidity ^0.4.17;

// mapping side of users: {0: not in group, 1: in group but not paid for any active periods, 2: in group and paid}

minGroupSize = 12;

contract Tandapay {

    struct Period {
        uint phase;
        uint startTime;
    }

struct Group  {
    uint groupId;
    address secretary;
    address[] userList; // For resetting the mapping when changing over all of the users
    mapping(address => uint) userMapping; // For individual transactions with users i.e. paying, checking whether a user is in the Group
    uint count;
    uint premium;
    uint maxClaim;
    Period oldPeriod;
    Period newPeriod;
    uint etherBalance;
}       

Group[] public groups;
address public administrator;
uint public groupIndex; //count
    
function Tandpay() {
administrator = msg.sender;
}

function makeGroup(address secretary, address[] policyholders, uint premium, uint maxClaim) {
    require(policyholders.length >= minGroupSize);
    require(maxClaim <= premium * policyholders.length);
    Group memory newGroup = Group({
        groupId: groupIndex,
        secretary: secretary, 
        policyholders: policyholders,
        premium: premium,
        maxClaim: maxClaim
        period: 0,
        periodStartTime: now,
        etherBalance: 0
    });
    groupIndex += 1;
    // add group
}

function sendPremium(uint groupId) payable {
    require(groups[groupId …. is not null);
    require(groups[groupId]... contains msg.sender);
    require(groups[groupId].state == … pre preiod);
    require(msg.value == groups[groupId].premium);
    require(
}

function “A Secretary can initiate a period for policyholders to send in their premiums” {
require(msg.sender == groups[groupId].secretary);

}

function “A Secretary can start the active period” {
stuff
}

function “A Secretary can end the active period and start the post period” {
    stuff
}
    
}

