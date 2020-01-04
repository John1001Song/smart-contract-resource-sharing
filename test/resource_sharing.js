var resourseSharing = artifacts.require("./ResourceSharing.sol");

contract("ResourceSharing", function(accounts) {
  var rsInstance;

  it("initializes resource sharing", function() {
    return resourseSharing.deployed().then(function(instance) {
      rsInstance = instance;
      return rsInstance.test();
    }).then(function(iseq) {
      console.log("iseq=" + iseq);
      console.log("json=", JSON.stringify(iseq))
    });
  });
});