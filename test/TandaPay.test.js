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
  });

  describe('Test Happy Paths', function() {
    before( async function() {
      secretary = accounts[1];
      // Create a new group
      groupCreateEvent = await tandapay.methods.makeGroup(secretary, accounts, premium,
         premium * accounts.length)
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

      it('does not allow active period to end before 30 days', async function() {
        await truffleAssert.reverts(
          tandapay.methods.endActivePeriod(0, false).send({
            from: secretary, gas: '1000000'
          })
        );
      });
      
      it('allows a user to file a claim');
      
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

      // it('does an end to end test of the period and claim functionality', async function() {
      //   this.timeout(0);  // Disable timeouts for this test to prevent timeout error
      //                     // See: https://github.com/mochajs/mocha/issues/2025
      //   // Start group pre-period
      //   await tandapay.methods.startPrePeriod(0).send({
      //     from:secretary, gas: '1000000'
      //   });

      //   let premium = await tandapay.methods.getGroupPremium(0).call();
      //   //Pay all premiums
      //   for (let i = 0; i < minGroupSize; i++) {
      //     let premiumPaidEvent = null
      //     premiumPaidEvent = await tandapay.methods.sendPremium(0).send({
      //       value: premium,
      //       from: accounts[i]
      //     });
      //     assert.ok(premiumPaidEvent.events['PremiumPaid'])
      //   }
      //   paidCount = await tandapay.methods.getGroupPaidCount(0).call();
      //   assert.equal(minGroupSize, paidCount);

      //   //Start active period
      //   await tandapay.methods.startActivePeriod(0).send({
      //     from: secretary, gas: '1000000'
      //   });
      //   isActive = await tandapay.methods.isGroupActive(0).call();
      //   assert.equal(true, isActive);

      //   // End Active period
      //   await tandapay.methods.endActivePeriod(0, false).send({
      //     from: secretary, gas: '1000000'
      //   });
      //   isActive = await tandapay.methods.isGroupActive(0).call();
      //   assert.equal(false, isActive);
      // });
    });
  });
  
  describe('Test makeGroup "require" statements', function () {
    it('only allows the admin to create a group', async function() {
      await truffleAssert.reverts(
        tandapay.methods.makeGroup(secretary, accounts, premium, premium * accounts.length)
        .send({from: nonSpecialAccount, gas: '1000000'})
      );
    });

    it('enforces the minimum group size of ' + minGroupSize.toString, async function() {
      shortenedAccounts = accounts.slice(0, 11);
      await truffleAssert.reverts(
        tandapay.methods.makeGroup(admin, shortenedAccounts, premium, premium * shortenedAccounts.length)
        .send({from: nonSpecialAccount, gas: '1000000'})
      );
    });

    it('enforces the max claim is <= the group size * the premium', async function () {
      await truffleAssert.reverts(
        tandapay.methods.makeGroup(admin, accounts, premium, 2 * premium * accounts.length)
        .send({from: nonSpecialAccount, gas: '1000000'})
      );
    });

    it('enforces the policyholder accounts are unique', async function () {
      repeatedAccounts = accounts.slice();
      repeatedAccounts.push(accounts[0]);
      await truffleAssert.reverts(
        tandapay.methods.makeGroup(admin, accounts, premium, 2 * premium * accounts.length)
        .send({from: nonSpecialAccount, gas: '1000000'})
      );
    });

  });
  // describe('TandaPay Contract', function () {

  //   it('start pre-period, pay all premiums, start active period, and end active period', async function() {
  //     this.timeout(0);  // Disable timeouts for this test to prevent timeout error
  //                       // See: https://github.com/mochajs/mocha/issues/2025
  //     // Start group pre-period
  //     await tandapay.methods.startPrePeriod(0).send({
  //       from:secretary, gas: '1000000'
  //     });

  //     let premium = await tandapay.methods.getGroupPremium(0).call();
  //     //Pay all premiums
  //     for (let i = 0; i < minGroupSize; i++) {
  //       let premiumPaidEvent = null
  //       premiumPaidEvent = await tandapay.methods.sendPremium(0).send({
  //         value: premium,
  //         from: accounts[i]
  //       });
  //       assert.ok(premiumPaidEvent.events['PremiumPaid'])
  //     }
  //     paidCount = await tandapay.methods.getGroupPaidCount(0).call();
  //     assert.equal(minGroupSize, paidCount);

  //     //Start active period
  //     await tandapay.methods.startActivePeriod(0).send({
  //       from: secretary, gas: '1000000'
  //     });
  //     isActive = await tandapay.methods.isGroupActive(0).call();
  //     assert.equal(true, isActive);

  //     // End Active period
  //     await tandapay.methods.endActivePeriod(0, false).send({
  //       from: secretary, gas: '1000000'
  //     });
  //     isActive = await tandapay.methods.isGroupActive(0).call();
  //     assert.equal(false, isActive);
  //   });
  // });
});
