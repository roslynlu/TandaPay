pragma solidity ^0.4.21;

contract ERC20Interface {
   
   event Transfer(address indexed from, address indexed to, uint tokens);
   event Approval(address indexed tokenOwner, address indexed spender, uint tokens);
	
    address public admin;
    uint public total_supply;
    mapping (address => uint) public userBalance;
    mapping (address => uint) public approveBalance;
    mapping (address => mapping (address => uint)) public allowance;
    

    function ERC20Interface() public{
        admin = msg.sender;
	total_supply = 0;
    }
    

    function totalSupply() public view returns (uint){
        return total_supply;
    }

    function balanceOf(address tokenOwner) public view returns (uint){
        return userBalance[tokenOwner];
    }
    
    function allowance(address tokenOwner, address spender) public view returns (uint){
        return allowance[tokenOwner][spender];
    }

    function transfer(address to, uint tokens) public returns (bool){
    	require(userBalance[msg.sender] > 0);
    	require(userBalance[msg.sender] >= tokens);

	userBalance[msg.sender] -= tokens;
	userBalance[to] += tokens;

	emit Transfer(msg.sender, to, tokens);
        return true;
    }

    function approve(address sender, address spender, uint tokens) public returns (bool){
        require(userBalance[sender] > 0);
	require(userBalance[sender] >= tokens);
	require((approveBalance[sender] + tokens) <= userBalance[sender]);

	approveBalance[sender] += tokens;
	allowance[sender][spender] += tokens;

	emit Approval(sender, spender, tokens);
	return true;
    }

    function transferFrom(address from, address to, uint tokens) public returns (bool){
    	require(allowance[from][to] > 0);
	require(allowance[from][to] <= tokens);

	userBalance[from] -= tokens;
	userBalance[to] += tokens;
	allowance[from][to] -= tokens;
	approveBalance[from]  -= tokens;

	emit Transfer(from, to, tokens);
	return true;	
    }

    function deposit(address to, uint tokens) public returns (bool){
    	require(msg.sender == to);

	userBalance[to] += tokens;
	total_supply += tokens;
	
        return true;
    }

    //function withraw() depends on how this interacts with Tandapay
}

contract Tandapay {
    uint public minGroupSize = 10; //Set 10 for testing purpose
    ERC20Interface public PlaceholderContract;

    event GroupCreated(uint groupId);
    event PremiumPaid(uint groupId, address policyholder, uint period);
    event ClaimFiled(uint groupId, uint claimId);
    event ClaimReviewed(uint groupId, uint claimId, bool accepted);

    struct Period {
        bool active;
        uint startTime;
    }
    
    struct userState {
        uint nextPremium; // next period they need to pay premiums 
        uint latestClaim; // period of last claim made
    }

    struct Claim {
        string description;
        address policyholder;
        uint claimAmount;
        uint period;
        int claimState;
    }

    struct Group {
        uint groupId;
        address secretary;
        mapping(address => userState) userMapping;
        mapping(uint => Claim) claimMapping; 
        uint paidPremiumCount;
        uint premium;
        uint currentPremium;
        uint maxClaim;
        Period prePeriod;
        Period activePeriod;
        Period postPeriod;
        uint balance;
        uint claimBalance;
        uint periodCount; // Which period group is currently in, starts at 1
        uint claimIndex; // Id to be given to next claim filed, starts at 0
        uint activeClaimCount;
        uint postClaimCount;
        uint policyholderCount;
    }

    Group[] groups;
    address public administrator;
    uint public groupIndex; // Index into groups array of next created group 

    modifier secretaryOnly(uint groupId) {
        require(groups[groupId].secretary == msg.sender);
        _;
    }

    function Tandapay() public {
        administrator = msg.sender;
        groupIndex = 0;
    }

    function makeGroup(address _secretary, address[] policyholders, uint _premium, uint _maxClaim) public {
        require(msg.sender == administrator);
        require(policyholders.length >= minGroupSize);
        require(_maxClaim <= _premium * policyholders.length);

        Group memory newGroup = Group({
            groupId: groupIndex,
            secretary: _secretary,
            paidPremiumCount: 0,
            premium: _premium,
            currentPremium: _premium ,
            maxClaim: _maxClaim,
            prePeriod: Period(false, now),
            activePeriod: Period(false, now),
            postPeriod: Period(false, now),
            balance: 0,
            claimBalance: 0,
            periodCount: 1,
            claimIndex: 0,
            activeClaimCount: 0,
            postClaimCount: 0,
            policyholderCount: policyholders.length
        });

        groups.push(newGroup);

        Group storage currentGroup = groups[groupIndex];
        for (uint i = 0; i < policyholders.length; i++) {
            // Enforce uniqueness of policyholders
            require(currentGroup.userMapping[policyholders[i]].nextPremium == 0);
            
            // initial periodCount is 1
            // users map to 1 to indicate they have to pay premiums for period 1
            currentGroup.userMapping[policyholders[i]] = userState(1, 0);
        }
        require(currentGroup.userMapping[_secretary].nextPremium == 1); // Checks if secreatry was one of the passed in policyholders

        emit GroupCreated(groupIndex); 
        
        groupIndex += 1;
    }

    // A Secretary can initiate a period for policyholders to send in their premiums
    function startPrePeriod(uint groupId) public secretaryOnly(groupId) {
        Group storage currentGroup = groups[groupId];

        currentGroup.prePeriod = Period(true, now);
        currentGroup.postPeriod = Period(false, now);
    
        // Calculate the new premium from leftover balance
        currentGroup.currentPremium = (currentGroup.premium*currentGroup.policyholderCount - (currentGroup.balance - currentGroup.claimBalance)) / currentGroup.policyholderCount;

        /////////////////////////////////////////////
        // TODO: add logic that enforces 3 day window
        /////////////////////////////////////////////
    }

    // A policyholder can send a premium payment to a group
    // Remove payable when using erc20
    function sendPremium(uint groupId) public payable {
        Group storage currentGroup = groups[groupId]; //If groupId is not valid, errors here
        //////////////////////////////////////////////////
        require(msg.value == currentGroup.currentPremium);
        //////////////////////////////////////////////////
        // Replace above with:
        // PlaceholderContract.approve(this, currentGroup.currentPremium);
        // require(PlaceholderContract.transferFrom(msg.sender, this, currentGroup.currentPremium));
        require(currentGroup.prePeriod.active);
        require(currentGroup.userMapping[msg.sender].nextPremium == currentGroup.periodCount); // User is part of group and has not paid the premium
        
        // What if new premium is 0?
        currentGroup.userMapping[msg.sender].nextPremium++;
        currentGroup.balance += msg.value;
        currentGroup.paidPremiumCount += 1;
        
        emit PremiumPaid(currentGroup.groupId, msg.sender, currentGroup.periodCount);
    }

    // A Secretary can start the active period
    function startActivePeriod(uint groupId) public secretaryOnly(groupId){
        Group storage currentGroup = groups[groupId];//If groupId is not valid, errors here
        
        // require(currrentGroup.postClaimCount == 0)
        
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
            /////////////////////////////////////////////////
            // I have no idea what is supposed to happen here
            /////////////////////////////////////////////////
            require(currentGroup.activeClaimCount == 0); // No claims have been filed
        }

        require(currentGroup.activePeriod.active);
        require(currentGroup.postClaimCount == 0); // all claims from previous period have been reviewed
        require(currentGroup.activePeriod.startTime <= now - 30 days);

        currentGroup.activePeriod.active = false;
        currentGroup.postPeriod = Period(true, now);
        currentGroup.postClaimCount = currentGroup.activeClaimCount;
        currentGroup.activeClaimCount = 0;

        if (continueToPeriod) {
            startActivePeriod(groupId);
        }
    }

    // A policyholder can file a claim during the active period
    function fileClaim(uint groupId, uint claimAmount, string claimDescription) public {
        Group storage currentGroup = groups[groupId];

        require(claimAmount <= currentGroup.balance - currentGroup.claimBalance);
        require(currentGroup.userMapping[msg.sender].latestClaim != currentGroup.periodCount - 1);
        require(currentGroup.userMapping[msg.sender].nextPremium == currentGroup.periodCount); // user has paid premium
        require(currentGroup.activePeriod.active);
        
        currentGroup.claimMapping[currentGroup.claimIndex] = Claim(
            claimDescription, msg.sender, claimAmount, currentGroup.periodCount - 1, 0
        );
        currentGroup.claimBalance += claimAmount;
        currentGroup.userMapping[msg.sender].latestClaim = currentGroup.periodCount - 1;
        currentGroup.activeClaimCount++;
    
        emit ClaimFiled(currentGroup.groupId, currentGroup.claimIndex);

        currentGroup.claimIndex++;  
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
            /////////////////////////////////////////////////////////////
            // Replace above with:
            // require(PlaceholderContract.transfer(currentClaim.policyholder, currentClaim.claimAmount));
            
            currentGroup.balance -= currentClaim.claimAmount;
        }
        else {
            currentClaim.claimState = -1;
        }
        
        currentGroup.claimBalance -= currentClaim.claimAmount;
        currentGroup.postClaimCount--;
        
        emit ClaimReviewed(currentGroup.groupId, claimId, accept);
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

    function getCurrentPremium(uint groupId) public view returns(uint) {
        return groups[groupId].currentPremium;
    }

    function getClaimBalance(uint groupId) public view returns(uint) {
        return groups[groupId].claimBalance;
    }
}
