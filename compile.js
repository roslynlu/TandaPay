const path = require('path');
const fs = require('fs');
const solc = require('solc');

const path = path.resolve(__dirname, 'contracts', 'TandaPay.sol');
const source = fs.readFileSync(path, 'utf8');

module.exports = solc.compile(source, 1).contracts[':TandaPay'];



