# TandaPay
## What is this?
This project was created through a collaboration between UCLA CS undergrads and the TandaPay team (Joshua Davis and [Michael Lewellan](https://github.com/cylon56)) as a course project for CS 130, Software Engineering at UCLA. It implements a core subset of the TandaPay insurance protocol, as imagined and specified by Joshua Davis in [this article](https://medium.com/@joshuadavis31/say-goodbye-to-the-500-deductible-5bbd2585ce7f) and others on his Medium profile. In brief, TandaPay is designed to be a peer-to-peer insurance protocol that runs on the Ethereum blockchain. The decentralized nature of TandaPay is aimed at reducing overhead costs and making TandaPay harder to regulate. While this Smart Contract implementation does not have some very important features for a truly functional TandaPay, the goal of the project was to 

a.) serve as an introduction to Ethereum-based development for the UCLA team, and 

b.) be a clear, readable implementation of the core functionality of TandaPay, so another team could have a starting point for a more complete implementation of TandaPay.

## How to get this repo running?

0. Note that Node v10+ is a requirement for running this code
1. `$ git clone` the repo to your local computer
2. navigate to the directory you cloned into (e.g. `$ cd TandaPay`)
3. Run `$ npm install` within the top-level directory
4. `$ npm run test` will run all the tests available for the smart contracts

In order to deploy these contracts to an Ethereum network (e.g. Rinkeby, main net), you would need to add some deployment code (potentially as deploy scripts). See Stephen Grider's Ethereum course for some simple examples of deploy scripts
