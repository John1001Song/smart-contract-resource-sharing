pragma solidity 0.5.12;

contract LinkedList {
    event AddEntry(bytes32 head,uint number, string name,bytes32 next);

    uint public length = 0;//also used as nonce

    struct Object{
        bytes32 next;
        uint number;
        string name;
    }

    bytes32 public head;
    mapping (bytes32 => Object) public objects;

    constructor() public {
        addEntry(111, "test");
    }

    function addEntry(uint _number, string memory _name) public returns (bool){
        Object memory object = Object(head,_number,_name);
        bytes32 id = keccak256(abi.encodePacked(object.name));
        objects[id] = object;
        head = id;
        length = length+1;
        emit AddEntry(head,object.number,object.name,object.next);
    }

    function getHead() public returns (bytes32) {
        return head;
    }

    function getName(bytes32 _id) public returns (string memory) {
        return objects[_id].name;
    }

    //needed for external contract access to struct
    function getEntry(bytes32 _id) public returns (bytes32,uint,string memory){
        return (objects[_id].next,objects[_id].number,objects[_id].name);
    }

    //------------------ totalling stuff to explore list mechanics 

    function total() public view returns (uint) {
        bytes32 current = head;
        uint totalCount = 0;
        while( current != 0 ){
            totalCount = totalCount + objects[current].number;
            current = objects[current].next;
        }
        return totalCount;
    }

    function setTotal() public returns (bool) {
        writtenTotal = total();
        return true;
    }

    function resetTotal() public returns (bool) {
        writtenTotal = 0;
        return true;
    }

    uint public writtenTotal;
}