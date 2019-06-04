const assert = require('assert');
const ganache = require('ganache-cli');
const Web3 = require('web3');
const truffleAssert = require('truffle-assertions')
const provider = ganache.provider();
// To remove a MaxListenersExceededWarning
provider.setMaxListeners(12);

const web3 = new Web3(provider);
const { interface, bytecode } = require('../compile');

let tandapay;
let accounts;
let admin;
let secretary;
let minGroupSize = 10;
let groupCreateEvent;
let premium = 1;
let nonSpecialAccount;
let maxClaim;

describe('TandaPay Contract Test Suite', function() {
  // Nested describe statements are allowed and make for a clearer delineation of tests
  before( async function() {
    // Getting more than 10 accounts out of this function is wayyy
    // harder than it needs to be - involves creating more personal accounts
    // then adding eth to all them - not worth the trouble
    accounts = await web3.eth.getAccounts();
    admin = accounts[0];
    nonSpecialAccount = accounts[3];
    // Deploy the contract
    tandapay = await new web3.eth.Contract(JSON.parse(interface))
      .deploy( {data: bytecode })
      .send( {from: admin, gas: '5000000'});
    maxClaim = premium * accounts.length;
  });

  describe('Test Happy Paths', function() {
    before( async function() {
      secretary = accounts[1];
      // Create a new group
      groupCreateEvent = await tandapay.methods.makeGroup(secretary, accounts, premium,
         maxClaim)
        .send({from: admin, gas: '1000000'});
    });
    
    describe('Test Basic Deployment/Group Creation', async function () {
      it('deploys a contract', function () {
        assert.ok(tandapay.options.address);
        assert.ok(groupCreateEvent.events['GroupCreated']);
      });

      it('checks admin in contract = original admin', async function () {
        contractAdmin = await tandapay.methods.administrator().call();
        assert.equal(admin, contractAdmin);
      });

      it('checks secretary in contract = original secretary', async function () {
        groupSecretary = await tandapay.methods.getGroupSecretary(0).call();
        assert.equal(secretary, groupSecretary);
      });

      it('adds members besides secretary', async function () {
        isMember = await tandapay.methods.isMember(0, nonSpecialAccount).call();
        assert.ok(isMember);
      });

      it('sets the premium to the desired value', async function () {
        contractPremium = await tandapay.methods.getGroupPremium(0).call();
        assert.equal(contractPremium, premium);
      });
    });

    describe('Test Full Period and Claim Process', async function () {
      it('only lets the secretary start a pre-period', async function () {
        await truffleAssert.reverts(
          tandapay.methods.startPrePeriod(0).send({
            from: nonSpecialAccount, gas: '1000000'
          })
        );
      });

      it('successfully starts the pre-period', async function () {
        await tandapay.methods.startPrePeriod(0).send({
          from:secretary, gas: '1000000'
        });
        prePeriodStarted = await tandapay.methods.prePeriodStart(0);
        assert.ok(prePeriodStarted);
      });

      it('stops active period from starting until premiums are paid', async function () {
        await truffleAssert.reverts(
          tandapay.methods.startActivePeriod(0).send({ from: secretary, gas: '1000000'})
        );
      });

      it('lets the secretary start active period once premiums are paid', async function () {
        let premium = await tandapay.methods.getGroupPremium(0).call();
          //Pay all premiums
        for (let i = 0; i < accounts.length; i++) {
          let premiumPaidEvent = null
          premiumPaidEvent = await tandapay.methods.sendPremium(0).send({
            value: premium,
            from: accounts[i]
          });
          assert.ok(premiumPaidEvent.events['PremiumPaid'])
        }
        paidCount = await tandapay.methods.getGroupPaidCount(0).call();
        assert.equal(minGroupSize, paidCount);
        await tandapay.methods.startActivePeriod(0).send({
          from: secretary, gas: '1000000'
        });
        isActive = await tandapay.methods.isGroupActive(0).call();
        assert.ok(isActive);
      });

      it('requires claims are less than maxClaim', async function() {
          await truffleAssert.reverts(
            tandapay.methods.fileClaim(0, maxClaim+1, "this is totally not fraud").send({
            from: nonSpecialAccount, gas: '1000000'
          })
        );
      });

      it('allows a user to file a claim', async function() {
        await tandapay.methods.fileClaim(0, maxClaim/2, "this is a real claim").send({
            from: nonSpecialAccount, gas: '1000000'
        });
      });

      it('does not allow a user to file multiple claims in 1 period', async function() {
        await truffleAssert.reverts(
          tandapay.methods.fileClaim(0, maxClaim/2, "this is a real claim").send({
            from: nonSpecialAccount, gas: '1000000'
          })
        );
      });

      it('does not allow active period to end before 30 days', async function() {
        await truffleAssert.reverts(
          tandapay.methods.endActivePeriod(0, false).send({
            from: secretary, gas: '1000000'
          })
        );
      });
      
      //Note that this 
      it('lets the secretary end the active period after 30 days', async function () {
        await web3.currentProvider.send({
            jsonrpc: '2.0',
            method: 'evm_increaseTime',
            params: [2635000],
            id: 0,
          }, () => {});
        await tandapay.methods.endActivePeriod(0, false).send({
          from: secretary, gas: '1000000'
        });
        isActive = await tandapay.methods.isGroupActive(0).call();
        assert.equal(false, isActive);
      });

      it('does not let regular users review claims', async function () {
        await truffleAssert.reverts(
          tandapay.methods.reviewClaim(0, 1, true).send({
            from: nonSpecialAccount, gas: '1000000'
          })
        );
      });

      it('lets the secretary review claims', async function () {
        await tandapay.methods.reviewClaim(0, 1, true).send({
            from: secretary, gas: '1000000'
        });
      });
    });
  });
  
  describe('Test makeGroup "require" statements', function () {
    it('only allows the admin to create a group', async function() {
      await truffleAssert.reverts(
        tandapay.methods.makeGroup(secretary, accounts, premium, maxClaim)
        .send({from: nonSpecialAccount, gas: '1000000'})
      );
    });

    it('enforces the minimum group size of ' + minGroupSize.toString(), async function() {
      shortenedAccounts = accounts.slice(0, minGroupSize-1);
      await truffleAssert.reverts(
        tandapay.methods.makeGroup(secretary, shortenedAccounts, premium, premium * shortenedAccounts.length)
        .send({from: admin, gas: '1000000'})
      );
    });

    it('enforces the max claim is <= the group size * the premium', async function () {
      await truffleAssert.reverts(
        tandapay.methods.makeGroup(secretary, accounts, premium, 2 * maxClaim)
        .send({from: admin, gas: '1000000'})
      );
    });

    it('enforces the policyholder accounts are unique', async function () {
      repeatedAccounts = accounts.slice();
      repeatedAccounts.push(accounts[0]);
      await truffleAssert.reverts(
        tandapay.methods.makeGroup(secretary, repeatedAccounts, premium, maxClaim)
        .send({from: admin, gas: '1000000'})
      );
    });

  });
});
