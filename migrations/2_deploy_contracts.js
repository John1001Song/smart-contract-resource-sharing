var linkedList = artifacts.require("./LinkedList.sol");

module.exports = function(deployer) {
  deployer.deploy(linkedList);
};