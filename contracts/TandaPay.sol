pragma solidity ^0.4.17;


contract Tandapay {
    uint public minGroupSize = 12;
    enum Phase {INACTIVE, PRE, ACTIVE, POST}
    // userMapping code: {0: not in group, 1: in group but not paid for any active periods, 2: in group and paid}
    
    struct Period {
        Phase phase;
        uint startTime;
    }

    struct Group  {
        uint groupId;
        address secretary;
        address[] userList; // For resetting the mapping when changing over all of the users
        mapping(address => uint) userMapping; // For individual transactions with users i.e. paying, checking whether a user is in the Group
        uint paidPremiumCount;
        uint premium;
        uint maxClaim;
        Period oldPeriod;
        Period newPeriod;
        uint currentPeriod; // Which Period is in the active phase
        uint etherBalance;
    }       
    
    Group[] groups;
    address public administrator;
    uint public groupIndex; //count
        
    function Tandpay() public {
        administrator = msg.sender;
    }
    
    function makeGroup(address secretary, address[] policyholders, uint premium, uint maxClaim) public {
        require(policyholders.length >= minGroupSize);
        require(maxClaim <= premium * policyholders.length);
        
        Group memory newGroup = Group({
            groupId: groupIndex,
            secretary: secretary, 
            userList: policyholders,
            paidPremiumCount: 0,
            premium: premium,
            maxClaim: maxClaim,
            oldPeriod: Period(Phase.INACTIVE, now),
            newPeriod: Period(Phase.PRE, now),
            currentPeriod: 2, // Initialize group with newPeriod as the currentPeriod so that only newPeriod can be in the PRE phase
            etherBalance: 0
        });
        groupIndex += 1;
        
        groups.push(newGroup);
    }
    
    // A Secretary can initiate a period for policyholders to send in their premiums
    function startPrePeriod(uint groupId) public{
        require(msg.sender == groups[groupId].secretary);
        
    }
    
    // A policyholder can send a premium payment to a group
    function sendPremium(uint groupId) public payable {
        require(groups.length >= groupId); // Check if groupId is valid. Bobo implementation. Should be changed.
        require(groups[groupId].userMapping[msg.sender] != 0);
        require(groups[groupId].newPeriod.phase == Phase.PRE); // Assume any Period in pre-period phase is the newPeriod
        require(msg.value == groups[groupId].premium);
        // require(polyholder has not already paied premium)
    }
    
    // A Secretary can start the active period
    function startActivePeriod() public {
        require(true);
    }
    
    // A Secretary can end the active period and start the post period
    // The secretary also has the option to continue to another period if there have been no claims
    function endActivePeriod() public {
        require(true);
    }
    
}