const betDapp = artifacts.require("betDapp");

module.exports = function(deployer) {
  deployer.deploy(betDapp).then(function(instance){
    instance.loadContract({value: web3.utils.toWei('10','ether')})
  });
};
