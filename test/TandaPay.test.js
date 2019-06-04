const assert = require('assert');
const ganache = require('ganache-cli');
const Web3 = require('web3');
const truffleAssert = require('truffle-assertions')
const provider = ganache.provider([
  // Add 12 accounts so we can enforce a min group size of 12
  { 'balance': 0x56bc75e2d63100000 }, // Account 1
  { 'balance': 0x56bc75e2d63100000 }, // Account 2
  { 'balance': 0x56bc75e2d63100000 }, // Account 3
  { 'balance': 0x56bc75e2d63100000 }, // Account 4
  { 'balance': 0x56bc75e2d63100000 }, // Account 5
  { 'balance': 0x56bc75e2d63100000 }, // Account 6
  { 'balance': 0x56bc75e2d63100000 }, // Account 7
  { 'balance': 0x56bc75e2d63100000 }, // Account 8
  { 'balance': 0x56bc75e2d63100000 }, // Account 9
  { 'balance': 0x56bc75e2d63100000 }, // Account 10
  { 'balance': 0x56bc75e2d63100000 }, // Account 11
  { 'balance': 0x56bc75e2d63100000 }, // Account 12
  { 'balance': 0x56bc75e2d63100000 } 
]);
// To remove a MaxListenersExceededWarning
provider.setMaxListeners(12);

const web3 = new Web3(provider);
const { interface, bytecode } = require('../compile');

let tandapay;
let accounts;
let admin;
let secretary;
let minGroupSize = 12;
let groupCreateEvent;
let premium = 1;
let nonSpecialAccount;

describe('TandaPay Contract Test Suite', function() {
  // Nested describe statements are allowed and make for a clearer delineation of tests
  before( async function() {
    accounts = await web3.eth.getAccounts();
    admin = accounts[0];
    nonSpecialAccount = accounts[3];
    // Deploy the contract
    tandapay = await new web3.eth.Contract(JSON.parse(interface))
      .deploy( {data: bytecode })
      .send( {from: admin, gas: '5000000'});
  });

  describe('Basic Deployment and Group Creation Tests', function() {
    before( async function() {
      secretary = accounts[1];
      // Create a new group
      groupCreateEvent = await tandapay.methods.makeGroup(secretary, accounts, premium, premium * accounts.length)
        .send({from: admin, gas: '5000000'});
    });

    it('deploys a contract', function () {
      assert.ok(tandapay.options.address);
      assert.ok(groupCreateEvent.events['GroupCreated']);
    });

    it('checks admin in contract = original admin', async function () {
      contractAdmin = await tandapay.methods.administrator().call();
      assert.equal(admin, contractAdmin);
    })

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
  
  describe('Test makeGroup "require" statements', function () {
    it('only allows the admin to create a group', async function() {
      await truffleAssert.reverts(tandapay.methods.makeGroup(secretary, accounts, premium, premium * accounts.length)
        .send({from: nonSpecialAccount, gas: '1000000'}));
    });

    it('enforces the minimum group size of ' + minGroupSize.toString, async function() {
      shortenedAccounts = accounts.slice(0, 11);
      await truffleAssert.reverts(tandapay.methods.makeGroup(admin, shortenedAccounts, premium, premium * shortenedAccounts.length)
        .send({from: nonSpecialAccount, gas: '1000000'}));
    });

    it('enforces the max claim is <= the group size * the premium', async function () {
      await truffleAssert.reverts(tandapay.methods.makeGroup(admin, accounts, premium, 2 * premium * accounts.length)
        .send({from: nonSpecialAccount, gas: '1000000'}));
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
