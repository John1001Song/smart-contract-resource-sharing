var resourseSharing = artifacts.require("./ResourceSharing.sol");

var rsInstance;
var start = Math.round(new Date().getTime() / 1000);
var maxMatchInterval = 100 * 1000;
var end = start + 300 * 1000;

function sleep(delay) {
  var start = (new Date()).getTime();
  while ((new Date()).getTime() - start < delay) {
    continue;
  }
}

function addProvider(accounts, num) {
  for (var i = 0; i < num; i ++) {
    var name = "Engagement #" + i;
    console.log("Add engagement: name=", name);
    rsInstance.addProvider(name, 1, start, start + 220 * 1000, { from: accounts[0] });
  }
}

function addConsumer(accounts, num) {
  for (var i = 0; i < num; i ++) {
    var name = "consumer #" + i;
    console.log("Add consumer, name:", name);
    rsInstance.addConsumer(name, 1, 100 * 1000, start + 300 * 1000, { from: accounts[1] });
  }
}
/*
contract("ResourceSharing", function(accounts) {
  var curBytes, provider;
  var num = 10;
  it("add " + num + " providers", function() {
    return resourseSharing.deployed().then(function(instance) {
      rsInstance = instance;
      rsInstance.reset();
      addProvider(accounts, num);
      return instance.head();
    }).then(function(head) {
      curBytes = head;
    });
  });

  for (var i = 0; i < num; i ++) {
    it("iter", function() {
      return resourseSharing.deployed().then(function(instance) {
        assert.notEqual(curBytes, 0x0);
        return rsInstance.providerList(curBytes);
      }).then(function(_provider) {
        provider = _provider;
        curBytes = provider.next;
      });
    })
  }

  it("check length", function() {
    assert.equal(curBytes, 0x0);
  })

  console.log(num, "providers added")

  it("add " + num + " consumer", function() {
    return resourseSharing.deployed().then(function(instance) {
      rsInstance = instance;
      addConsumer(accounts, num);
    });
  });

  it("check match length", function() {
    return resourseSharing.deployed().then(function(instance) {
      return rsInstance.matchings(accounts[0], num-1);
    }).then(function(match) {
      assert.equal(match.providerAddr, accounts[0]);
      assert.equal(match.consumerAddr, accounts[1]);
      return rsInstance.matchings(accounts[1], num-1);
    }).then(function(match) {
      assert.equal(match.providerAddr, accounts[0]);
      assert.equal(match.consumerAddr, accounts[1]);
      return rsInstance.matchings(accounts[0], num);
    }).then(assert.fail).catch(function(error) {
      assert(error.message.indexOf('revert') >= 0, "error message must contain revert");
      return rsInstance.matchings(accounts[1], num);
    }).then(assert.fail).catch(function(error) {
      assert(error.message.indexOf('revert') >= 0, "error message must contain revert");
    });
  })
});
*/