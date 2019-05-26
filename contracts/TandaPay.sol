pragma solidity ^0.4.17;


contract Tandapay {
    uint public minGroupSize = 12;
    enum Phase {INACTIVE, PRE, ACTIVE, POST}
    // userMapping code: {0: not in group, 1: in group but not paid for any active periods, 2: in group and paid}

    struct Period {
        Phase phase;
        uint startTime;
    }

    struct Group {
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

    mapping(uint => Group) groups;
    address public administrator;
    uint public groupIndex; //count
    
    modifier secretaryOnly(uint groupId) {
        require(groups[groupId].secretary == msg.sender);
        _;
    }
    
    modifier validId(uint groupId) {
        // groupIndex starts at 1, so all created groups have groupId greater than 0
        // I think this is how a mapping of structs works
        require(groups[groupId].groupId != 0); 
        _;
    }

    function Tandpay() public {
        administrator = msg.sender;
        groupIndex = 1;
    }

    function makeGroup(address secretary, address[] policyholders, uint premium, uint maxClaim) public {
        require(msg.sender == administrator);
        require(policyholders.length >= minGroupSize);
        require(maxClaim <= premium * policyholders.length);
        ///////////////////////////////////////////////////////////////////////////////////
        // Do we want to add a check to make sure all elements of policyholders are unique?
        // If there are duplicates, it messes up paidPremiumCount logic.
        //////////////////////////////////////////////////////////////////////////////////
        
        Group memory newGroup = Group({
            groupId: groupIndex,
            secretary: secretary,
            userList: policyholders,
            paidPremiumCount: 0,
            premium: premium,
            maxClaim: maxClaim,
            oldPeriod: Period(Phase.INACTIVE, now),
            newPeriod: Period(Phase.INACTIVE, now),
            currentPeriod: 2, // Initialize group with newPeriod as the currentPeriod so that only newPeriod can be in the PRE phase
            etherBalance: 0
        });
        
        groups[groupIndex] = newGroup;
        
        // Use userList to initialize userMapping
        Group storage currentGroup = groups[groupIndex];
        for (uint i = 0; i < currentGroup.userList.length; i++) {
            currentGroup.userMapping[currentGroup.userList[i]] = 1;
        }
        require(currentGroup.userMapping[secretary] == 1); // Checks if secreatry was one of the passed in policyholders
        
        groupIndex += 1;
    }

    // A Secretary can initiate a period for policyholders to send in their premiums
    function startPrePeriod(uint groupId) public secretaryOnly(groupId) validId(groupId) {
        Group storage currentGroup = groups[groupId];
        
        currentGroup.oldPeriod = currentGroup.newPeriod;
        currentGroup.newPeriod = Period(Phase.PRE, now);
    }

    // A policyholder can send a premium payment to a group
    function sendPremium(uint groupId) public payable validId(groupId) {
        Group storage currentGroup = groups[groupId];
        
        require(currentGroup.userMapping[msg.sender] == 1); // User is part of group and has not paid the premium
        require(currentGroup.newPeriod.phase == Phase.PRE); // Assume any Period in pre-period phase is the newPeriod
        require(msg.value == currentGroup.premium);
        
        currentGroup.userMapping[msg.sender] = 2;
        currentGroup.etherBalance += msg.value;
        currentGroup.paidPremiumCount += 1;
    }

    // A Secretary can start the active period
    function startActivePeriod(uint groupId) public secretaryOnly(groupId) validId(groupId){
        Group storage currentGroup = groups[groupId];
                
        require(currentGroup.paidPremiumCount == currentGroup.userList.length); //All premiums have been paid
        require(currentGroup.newPeriod.phase == Phase.PRE); //Group is not active
        
        currentGroup.newPeriod.phase = Phase.ACTIVE;
        currentGroup.currentPeriod = 2;
        // Reset userMapping
        for (uint i = 0; i < currentGroup.userList.length; i++) {
            currentGroup.userMapping[currentGroup.userList[i]] = 1;
        }
        currentGroup.paidPremiumCount = 0;
    }

    // A Secretary can end the active period and start the post period
    // The secretary also has the option to continue to another period if there have been no claims
    function endActivePeriod(uint groupId) public secretaryOnly(groupId) validId(groupId){
        Group storage currentGroup = groups[groupId];
        
        require(true);
    }

}
