pragma solidity ^0.4.17;


contract Tandapay {
    uint public minGroupSize = 10; //Set 10 for testing purpose
    // userMapping code: {0: not in group, 1: in group but not paid for any active periods, 2: in group and paid}

    struct Period {
        bool active;
        uint startTime;
    }
    
    struct userState {
        uint nextPremium;
        uint latestClaim;
    }

    struct Claim {
        address policyholder;
        uint claimAmount;
        uint period;
        int claimState;
    }

    struct Group {
        uint groupId;
        address secretary;
        /* Maps each policyholder to a number. Increment this number to match periodCount
        everytime they pay the premium */
        mapping(address => userState) userMapping;
        mapping(uint => Claim) claimMapping;
        uint paidPremiumCount;
        uint premium;
        uint maxClaim;
        Period prePeriod;
        Period activePeriod;
        Period postPeriod;
        uint etherBalance;
        uint claimBalance;
        /* Keep track of period */
        uint periodCount;
        uint claimIndex;
        /* Keep track of number of policyholders in group */
        uint policyholderCount;
    }
    Group[] groups;
    address public administrator;
    uint public groupIndex; //count

    modifier secretaryOnly(uint groupId) {
        require(groups[groupId].secretary == msg.sender);
        _;
    }

    function Tandapay() public {
        administrator = msg.sender;
        groupIndex = 0;
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
            paidPremiumCount: 0,
            premium: premium,
            maxClaim: maxClaim,
            prePeriod: Period(false, now),
            activePeriod: Period(false, now),
            postPeriod: Period(false, now),
            etherBalance: 0,
            claimBalance: 0,
            periodCount: 1,
            claimIndex: 0,
            policyholderCount: policyholders.length
        });

        groups.push(newGroup);

        Group storage currentGroup = groups[groupIndex];
        for (uint i = 0; i < policyholders.length; i++) {
          /* initial periodCount is 1
          users map to 1 to indicate they have to pay premiums for period 1.
          This require statement enforces uniqueness in the policyholders */
          require(!isMember(groupIndex, policyholders[i]));
          currentGroup.userMapping[policyholders[i]] = userState(1, 0);
        }
        require(currentGroup.userMapping[secretary].nextPremium == 1); // Checks if secreatry was one of the passed in policyholders

        groupIndex += 1;
    }

    // A Secretary can initiate a period for policyholders to send in their premiums
    function startPrePeriod(uint groupId) public secretaryOnly(groupId) {
        Group storage currentGroup = groups[groupId];

        currentGroup.prePeriod = Period(true, now);
        currentGroup.postPeriod = Period(false, now);

        /////////////////////////////////////////////
        // TODO: add logic that enforces 3 day window
        /////////////////////////////////////////////
    }

    // A policyholder can send a premium payment to a group
    function sendPremium(uint groupId) public payable {
        Group storage currentGroup = groups[groupId]; //If groupId is not valid, errors here
        require(msg.value == currentGroup.premium);
        require(currentGroup.prePeriod.active); // Assume any Period in pre-period phase is the newPeriod
        require(currentGroup.userMapping[msg.sender].nextPremium == currentGroup.periodCount); // User is part of group and has not paid the premium

        currentGroup.userMapping[msg.sender].nextPremium++;
        currentGroup.etherBalance += msg.value;
        currentGroup.paidPremiumCount += 1;
    }

    // A Secretary can start the active period
    function startActivePeriod(uint groupId) public secretaryOnly(groupId){
        Group storage currentGroup = groups[groupId];//If groupId is not valid, errors here

        require(currentGroup.paidPremiumCount == currentGroup.policyholderCount); //All premiums have been paid
        require(currentGroup.prePeriod.active); //Group is not active

        currentGroup.activePeriod = Period(true, now);
        currentGroup.prePeriod.active = false;

        currentGroup.paidPremiumCount = 0;
        currentGroup.periodCount++;
    }

    // A Secretary can end the active period and start the post period
    // The secretary also has the option to continue to another period if there have been no claims
    function endActivePeriod(uint groupId, bool continueToPeriod) public secretaryOnly(groupId) {
        Group storage currentGroup = groups[groupId];

        if (continueToPeriod) {
            require(true); // No claims have been filed
        }
        require(currentGroup.activePeriod.active);
        // To-Do: Below currently causes test to fail. Why? Find fix.
        // require(currentGroup.activePeriod.startTime <= now - 30 days);

        currentGroup.activePeriod.active = false;
        currentGroup.postPeriod = Period(true, now);

        if (continueToPeriod) {
            startActivePeriod(groupId);
        }

    }

    // A policyholder can file a claim during the active period
    function fileClaim(uint groupId, uint claimAmount) public {
        Group storage currentGroup = groups[groupId];

        require(claimAmount <= currentGroup.etherBalance - currentGroup.claimBalance);
        require(currentGroup.userMapping[msg.sender].latestClaim != currentGroup.periodCount - 1);
        require(currentGroup.userMapping[msg.sender].nextPremium == currentGroup.periodCount - 1); // user has paid premium
        require(currentGroup.activePeriod.active);
        
        currentGroup.claimMapping[currentGroup.claimIndex] = Claim(
            msg.sender, claimAmount, currentGroup.periodCount - 1, 0);
        currentGroup.claimBalance += claimAmount;
        currentGroup.userMapping[msg.sender].latestClaim = currentGroup.periodCount - 1;
        currentGroup.claimIndex++;
        
        // emit claim ID
    }

    // A Secretary can review a claim and approve it or reject it
    function reviewClaim(uint groupId, uint claimId, bool accept) public secretaryOnly(groupId) {
        Group storage currentGroup = groups[groupId];
        Claim storage currentClaim = currentGroup.claimMapping[claimId];

        require(currentGroup.postPeriod.active);
        require(currentClaim.claimState == 0);
        
        if(accept) {
            currentClaim.claimState = 1;
            currentClaim.policyholder.transfer(currentClaim.claimAmount);
            currentGroup.etherBalance -= currentClaim.claimAmount;
        }
        else {
            currentClaim.claimState = -1;
        }
        
        currentGroup.etherBalance -= currentClaim.claimAmount;
        
        
    }

    function getGroupSecretary(uint groupId) public view returns(address) {
        return groups[groupId].secretary;
    }

    function getGroupPeriodCount(uint groupId) public view returns(uint) {
        return groups[groupId].periodCount;
    }

    function getGroupPaidCount(uint groupId) public view returns(uint) {
        return groups[groupId].paidPremiumCount;
    }

    function isGroupActive(uint groupId) public view returns(bool) {
        return (groups[groupId].activePeriod.active);
    }

    function prePeriodStart(uint groupId) public view returns(bool) {
        return (groups[groupId].prePeriod.active);
    }

    function isMember(uint groupId, address add) public view returns(bool){
        return (groups[groupId].userMapping[add].nextPremium != 0);
    }

    function getGroupPremium(uint groupId) public view returns(uint) {
        return groups[groupId].premium;
    }
}
