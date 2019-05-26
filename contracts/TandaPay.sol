pragma solidity ^0.4.17;


contract Tandapay {
    uint public minGroupSize = 10; //Set 10 for testing purpose
    enum Phase {INACTIVE, PRE, ACTIVE, POST}
    // userMapping code: {0: not in group, 1: in group but not paid for any active periods, 2: in group and paid}

    struct Period {
        Phase phase;
        uint startTime;
    }

    struct Group {
        uint groupId;
        address secretary;
        /* Maps each policyholder to a number. Increment this number to match periodCount
        everytime they pay the premium */
        mapping(address => uint) userMapping;
        uint paidPremiumCount;
        uint premium;
        uint maxClaim;
        Period oldPeriod;
        Period newPeriod;
        uint currentPeriod; // Which Period is in the active phase
        uint etherBalance;
        /* Keep track of period */
        uint periodCount;
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
            oldPeriod: Period(Phase.INACTIVE, now),
            newPeriod: Period(Phase.INACTIVE, now),
            currentPeriod: 2, // Initialize group with newPeriod as the currentPeriod so that only newPeriod can be in the PRE phase
            etherBalance: 0,
            periodCount: 1,
            policyholderCount: policyholders.length
        });

        groups.push(newGroup);

        Group storage currentGroup = groups[groupIndex];
        for (uint i = 0; i < policyholders.length; i++) {
          /* initial periodCount is 1
          users map to 1 to indicate they have to pay premiums for period 1 */
          currentGroup.userMapping[policyholders[i]] = 1;
        }
        require(currentGroup.userMapping[secretary] == 1); // Checks if secreatry was one of the passed in policyholders

        groupIndex += 1;
    }

    // A Secretary can initiate a period for policyholders to send in their premiums
    function startPrePeriod(uint groupId) public secretaryOnly(groupId) {
        Group storage currentGroup = groups[groupId];

        currentGroup.oldPeriod = currentGroup.newPeriod;
        currentGroup.newPeriod = Period(Phase.PRE, now);
    }

    // A policyholder can send a premium payment to a group
    function sendPremium(uint groupId) public payable {
      Group storage currentGroup = groups[groupId]; //If groupId is not valid, errors here
      require(msg.value == currentGroup.premium);
      require(currentGroup.newPeriod.phase == Phase.PRE); // Assume any Period in pre-period phase is the newPeriod
      require(currentGroup.userMapping[msg.sender] == currentGroup.periodCount); // User is part of group and has not paid the premium

      currentGroup.userMapping[msg.sender]++;
      currentGroup.etherBalance += msg.value;
      currentGroup.paidPremiumCount += 1;
    }

    // A Secretary can start the active period
    function startActivePeriod(uint groupId) public secretaryOnly(groupId){
      Group storage currentGroup = groups[groupId];//If groupId is not valid, errors here

      require(currentGroup.paidPremiumCount == currentGroup.policyholderCount); //All premiums have been paid
      require(currentGroup.newPeriod.phase == Phase.PRE); //Group is not active

      currentGroup.newPeriod.phase = Phase.ACTIVE;
      currentGroup.currentPeriod = 2;

      currentGroup.paidPremiumCount = 0;
      currentGroup.periodCount++;
    }

    // A Secretary can end the active period and start the post period
    // The secretary also has the option to continue to another period if there have been no claims
    /*function endActivePeriod(uint groupId) public secretaryOnly(groupId) {
        Group storage currentGroup = groups[groupId];

        require(true);
    }*/

    function getGroupSecretary(uint groupId) public view returns(address) {
        return groups[groupId].secretary;
    }

    function getGroupPeriodCount(uint groupId) public view returns(uint) {
        return groups[groupId].periodCount;
    }

    function getGroupPaidCount(uint groupId) public view returns(uint) {
        return groups[groupId].paidPremiumCount;
    }

    function isActive(uint groupId) public view returns(bool) {
        return (groups[groupId].newPeriod.phase == Phase.ACTIVE);
    }

    function prePeriodStart(uint groupId) public view returns(bool) {
      return (groups[groupId].newPeriod.phase == Phase.PRE);
    }

    function isMember(uint groupId, address add) public view returns(bool){
      return (groups[groupId].userMapping[add] != 0);
    }

    function getGroupPremium(uint groupId) public view returns(uint) {
      return groups[groupId].premium;
    }
}
