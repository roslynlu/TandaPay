const assert = require('assert');
const ganache = require('ganache-cli');
const Web3 = require('web3');
const provider = ganache.provider({
    // This object allows us to specify 12 accounts intead of 10 for
    // the ganache provider
    accounts: [
        { balance: 0x56bc75e2d63100000 }, // Account 1
        { balance: 0x56bc75e2d63100000 }, // Account 2
        { balance: 0x56bc75e2d63100000 }, // Account 3
        { balance: 0x56bc75e2d63100000 }, // Account 4
        { balance: 0x56bc75e2d63100000 }, // Account 5
        { balance: 0x56bc75e2d63100000 }, // Account 6
        { balance: 0x56bc75e2d63100000 }, // Account 7
        { balance: 0x56bc75e2d63100000 }, // Account 8
        { balance: 0x56bc75e2d63100000 }, // Account 9
        { balance: 0x56bc75e2d63100000 }, // Account 10
        { balance: 0x56bc75e2d63100000 }, // Account 11
        { balance: 0x56bc75e2d63100000 }, // Account 12
    ]
});
const web3 = new Web3(provider);

const { interface, bytecode } = require('../compile');

let tandapay;
let accounts;
let admin;
let secretary;
let minGroupSize = 10;

beforeEach( async () => {
  accounts = await web3.eth.getAccounts();
  admin = accounts[0];
  secretary = accounts[0];
  // Deploy a contract
  tandapay = await new web3.eth.Contract(JSON.parse(interface))
    .deploy( {data: bytecode })
    .send( {from: admin, gas: '1000000 '});
  // Create a new group
  await tandapay.methods.makeGroup(secretary, accounts, 1, 1 * accounts.length)
    .send({from: admin, gas: '1000000'});
});

describe('TandaPay Contract', () => {
  it('deploys a contract', () => {
    assert.ok(tandapay.options.address);
  });

  it('check admin', async () => {
    contractAdmin = await tandapay.methods.administrator().call();
    assert.equal(admin, contractAdmin);
  })

  it('check group secretary', async () => {
    groupSecretary = await tandapay.methods.getGroupSecretary(0).call();
    assert.equal(secretary, groupSecretary);
  });

  it('is a member', async() => {
    isMember = await tandapay.methods.isMember(0, accounts[1]).call();
    assert.equal(true, isMember);
  });

  it('start pre-period, pay all premiums, start active period, and end active period', async function() {
    this.timeout(0);  // Disable timeouts for this test to prevent timeout error
                      // See: https://github.com/mochajs/mocha/issues/2025
    
    // Start group pre-period
    await tandapay.methods.startPrePeriod(0).send({
      from:secretary, gas: '1000000'
    });

    let premium = await tandapay.methods.getGroupPremium(0).call();
    //Pay all premiums
    for (let i = 0; i < minGroupSize; i++) {
      await tandapay.methods.sendPremium(0).send({
        value: premium,
        from: accounts[i]
      });
    }
    paidCount = await tandapay.methods.getGroupPaidCount(0).call();
    assert.equal(minGroupSize, paidCount);

    //Start active period
    await tandapay.methods.startActivePeriod(0).send({
      from: secretary, gas: '1000000'
    });
    isActive = await tandapay.methods.isGroupActive(0).call();
    assert.equal(true, isActive);

    // End Active period
    await tandapay.methods.endActivePeriod(0, false).send({
      from: secretary, gas: '1000000'
    });
    isActive = await tandapay.methods.isGroupActive(0).call();
    assert.equal(false, isActive);

  });

});
