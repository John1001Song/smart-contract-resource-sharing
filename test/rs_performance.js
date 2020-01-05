var resourseSharing = artifacts.require("./ResourceSharing.sol");

var rsInstance;
var start = Math.round(new Date().getTime() / 1000);
var end = 9999999999;
var maxMatchInterval = 100 * 1000;

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
    rsInstance.addProvider(name, 1, start, end, { from: accounts[0] });
  }
}

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
});