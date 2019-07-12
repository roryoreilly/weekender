const Weekender = artifacts.require("Weekender");

module.exports = function(deployer) {
  deployer.deploy(Weekender);
};
