pragma solidity 0.5.12;

import "./logger.sol";

contract ResourceSharing is Logger {
    event AddEntry(bytes32 head,uint number, string name,bytes32 next);

    uint public length = 0;//also used as nonce

    struct Provider{
        bytes32 id;
        bytes32 next;

        string name;
        uint target;
        uint start;
        uint end;
    }

    bytes32 public head;
    bool public iseq;
    mapping (bytes32 => Provider) public providerList;

    constructor() public {
        
    }

    function test() public returns (bool) {
        iseq = (head == 0x0);
        log("logging:", iseq);
        return iseq;
    }
}

