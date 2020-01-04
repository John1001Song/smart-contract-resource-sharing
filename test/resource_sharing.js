var resourseSharing = artifacts.require("./ResourceSharing.sol");

contract("ResourceSharing", function(accounts) {
  var rsInstance;

  it("add 3 providers consecutively", function() {
    return resourseSharing.deployed().then(function(instance) {
      rsInstance = instance;
      return rsInstance.addProvider("hello", 1, 2, 3);
    }).then(function(addEvent) {
      // console.log("json=", JSON.stringify(addEvent))
      return rsInstance.addProvider("world", 4, 5, 6);
    }).then(function(addEvent) {
      // console.log("json=", JSON.stringify(addEvent))
      return rsInstance.addProvider("test", 7, 8, 9);
    }).then(function(addEvent) {
      // console.log("json=", JSON.stringify(addEvent))
      return rsInstance.head();
    }).then(function(head) {
      return rsInstance.providerList(head);
    }).then(function(provider) {
      assert("hello", provider.name);
      assert(1, provider.target);
      assert(2, provider.start);
      assert(3, provider.end);
      return rsInstance.providerList(provider.next);
    }).then(function(provider) {
      assert("world", provider.name);
      assert(4, provider.target);
      assert(5, provider.start);
      assert(6, provider.end);
      return rsInstance.providerList(provider.next);
    }).then(function(provider) {
      assert("test", provider.name);
      assert(7, provider.target);
      assert(8, provider.start);
      assert(9, provider.end);
      assert('0x0', provider.next);
    });
  });
});