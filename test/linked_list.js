var linkedList = artifacts.require("./LinkedList.sol");

contract("LinkedList", function(accounts) {
  var linkedListInstance;

  it("initializes with two elements", function() {
    return linkedList.deployed().then(function(instance) {
      linkedListInstance = instance
      linkedListInstance.addEntry(123, "hello")
      return linkedListInstance.head();
    }).then(function(head) {
      console.log("head=" + head);
      return linkedListInstance.objects(head);
    }).then(function(obj) {
      assert("hello", obj.name);
      assert(obj.next);
      return obj.next;
    }).then(function(id) {
      console.log("id=" + id);
      return linkedListInstance.objects(id);
    }).then(function(obj) {
      assert("test", obj.name);
    });
  });
});
