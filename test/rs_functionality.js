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
  var maxMatchInterval = 100 * 1000;

  it("bad provider parameter end", function() {
    return resourseSharing.deployed().then(function(instance) {
      rsInstance = instance;
      return rsInstance.addProvider("hello", 1, 1, 1);
    }).then(assert.fail).catch(function(error) {
      assert(error.message.indexOf('revert') >= 0, "error message must contain revert");
    });
  });

  it("bad provider parameter start", function() {
    return resourseSharing.deployed().then(function(instance) {
      rsInstance = instance;
      return rsInstance.addProvider("hello", 1, 9999999999, 7999999999);
    }).then(assert.fail).catch(function(error) {
      assert(error.message.indexOf('revert') >= 0, "error message must contain revert");
    });
  });

  it("add providers", function() {
    return resourseSharing.deployed().then(function(instance) {
      rsInstance = instance;
      return rsInstance.addProvider("hello", 3, start+1, end, { from: accounts[0] });
    }).then(function(addEvent) {
      return rsInstance.addProvider("world", 2, start, end, { from: accounts[0] });
    }).then(function(addEvent) {
      return rsInstance.addProvider("test", 1, start, end, { from: accounts[0] });
    }).then(function(addEvent) {
      return rsInstance.addProvider("provider4", 4, start, end+1, { from: accounts[0] });
    }).then(function(addEvent) {
      return rsInstance.head();
    }).then(function(head) {
      return rsInstance.providerList(head);
    }).then(function(provider) {
      assert.equal(provider.name, "test");
      assert.equal(provider.target, 1);
      assert.equal(provider.start, start);
      assert.equal(provider.end, end);
      return rsInstance.providerList(provider.next);
    }).then(function(provider) {
      assert.equal(provider.name, "world");
      assert.equal(provider.target, 2);
      assert.equal(provider.start, start);
      assert.equal(provider.end, end);
      return rsInstance.providerList(provider.next);
    }).then(function(provider) {
      assert.equal(provider.name, "hello");
      assert.equal(provider.target, 3);
      assert.equal(provider.start, start+1);
      assert.equal(provider.end, end);
      return rsInstance.providerList(provider.next);
    }).then(function(provider) {
      assert.equal(provider.name, "provider4");
      assert.equal(provider.target, 4);
      assert.equal(provider.start, start);
      assert.equal(provider.end, end+1);
      assert.equal(provider.next, 0x0);
    });
  });

  it("remove expired providers", function() {
    return resourseSharing.deployed().then(function(instance) {
      rsInstance = instance;
      var start = Math.round(new Date().getTime() / 1000);
      rsInstance.addProvider("remove1", 1, start, start + 1);
      return rsInstance.head();
    }).then(function(head) {
      return rsInstance.providerList(head);
    }).then(function(provider) {
      assert.equal(provider.name, "remove1");
      sleep(2000);

      // test remove when adding
      var start = Math.round(new Date().getTime() / 1000);
      return rsInstance.addProvider("remove2", 1, start, start + 1);
    }).then(function(addProviderEvent) {
      sleep(2000);

      // test remove()
      rsInstance.removeExpiredProviders();
      return rsInstance.head();
    }).then(function(head) {
      return rsInstance.providerList(head);
    }).then(function(provider) {
      assert.equal(provider.name, "test");
    });
  });

  it("bad consumer parameter duration and deadline", function() {
    return resourseSharing.deployed().then(function(instance) {
      rsInstance = instance;
      return rsInstance.addConsumer("hello", 1, 1000, 1);
    }).then(assert.fail).catch(function(error) {
      assert(error.message.indexOf('revert') >= 0, "error message must contain revert");
    });
  });

  it("add consumer, reorder provider", function() {
    return resourseSharing.deployed().then(function(instance) {
      rsInstance = instance;
      rsInstance.addConsumer("consumer1", 2, 100, end, { from: accounts[1] })
      return rsInstance.head();
    }).then(function(head) {
      return rsInstance.providerList(head);
    }).then(function(provider) {
      assert.equal(provider.name, "test");
      assert.equal(provider.target, 1);
      return rsInstance.providerList(provider.next);
    }).then(function(provider) {
      assert.equal(provider.name, "hello");
      assert.equal(provider.target, 3);
      return rsInstance.providerList(provider.next);
    }).then(function(provider) {
      assert.equal(provider.name, "world");
      assert.equal(provider.target, 2);
      assert.equal(provider.start, start + maxMatchInterval + 100);
      assert.equal(provider.end, end);
      return rsInstance.providerList(provider.next);
    }).then(function(provider) {
      assert.equal(provider.name, "provider4");
      assert.equal(provider.target, 4);
      assert.equal(provider.next, 0x0);
      return rsInstance.matchings(accounts[0], 0);
    }).then(function(match) {
      assert.equal(match.providerName, "world");
      assert.equal(match.providerAddr, accounts[0]);
      assert.equal(match.consumerName, "consumer1");
      assert.equal(match.consumerAddr, accounts[1]);
      assert.equal(match.price, 2);
      assert.equal(match.start, start);
      assert.equal(match.duration, 100);
    });
  });
});
