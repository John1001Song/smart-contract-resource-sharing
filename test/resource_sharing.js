var resourseSharing = artifacts.require("./ResourceSharing.sol");

function sleep(delay) {
  var start = (new Date()).getTime();
  while ((new Date()).getTime() - start < delay) {
    continue;
  }
}

contract("ResourceSharing", function(accounts) {
  var rsInstance;
  var start = 7999999999;
  var end = 9999999999;

  it("add providers", function() {
    return resourseSharing.deployed().then(function(instance) {
      rsInstance = instance;
      return rsInstance.addProvider("hello", 1, start, end);
    }).then(function(addEvent) {
      // console.log("json=", JSON.stringify(addEvent))
      return rsInstance.addProvider("world", 2, start, end);
    }).then(function(addEvent) {
      // console.log("json=", JSON.stringify(addEvent))
      return rsInstance.addProvider("test", 3, start, end);
    }).then(function(addEvent) {
      // console.log("json=", JSON.stringify(addEvent))
      return rsInstance.head();
    }).then(function(head) {
      return rsInstance.providerList(head);
    }).then(function(provider) {
      assert("hello", provider.name);
      assert(1, provider.target);
      assert(start, provider.start);
      assert(end, provider.end);
      return rsInstance.providerList(provider.next);
    }).then(function(provider) {
      assert("world", provider.name);
      assert(4, provider.target);
      assert(start, provider.start);
      assert(end, provider.end);
      return rsInstance.providerList(provider.next);
    }).then(function(provider) {
      assert("test", provider.name);
      assert(7, provider.target);
      assert(start, provider.start);
      assert(end, provider.end);
      assert('0x0', provider.next);
    });
  });

  it("remove expired providers", function() {
    return resourseSharing.deployed().then(function(instance) {
      rsInstance = instance;
      var start = Math.round(new Date().getTime() / 1000) + 1;
      rsInstance.addProvider("hello", 1, start, start + 1);
      return rsInstance.head();
    }).then(function(head) {
      return rsInstance.providerList(head);
    }).then(function(provider) {
      assert("hello", provider.name);
      sleep(2000);
      rsInstance.addProvider("test", 3, start, end);
      return rsInstance.head();
    }).then(function(addEvent) {
      return rsInstance.head();
    }).then(function(head) {
      return rsInstance.providerList(head);
    }).then(function(provider) {
      assert("test", provider.name);
    });
  });

  it("bad parameter end", function() {
    return resourseSharing.deployed().then(function(instance) {
      rsInstance = instance;
      return rsInstance.addProvider("hello", 1, 1, 1);
    }).then(assert.fail).catch(function(error) {
      assert(error.message.indexOf('revert') >= 0, "error message must contain revert");
    });
  });

  it("bad parameter start", function() {
    return resourseSharing.deployed().then(function(instance) {
      rsInstance = instance;
      return rsInstance.addProvider("hello", 1, 9999999999, 7999999999);
    }).then(assert.fail).catch(function(error) {
      assert(error.message.indexOf('revert') >= 0, "error message must contain revert");
    });
  });
});