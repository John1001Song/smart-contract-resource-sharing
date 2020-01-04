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
    mapping (bytes32 => Provider) public providerList;

    constructor() public {}

    event AddProvider(bytes32 id, bytes32 next, string _name, uint _target, uint _start, uint _end);

    function addProvider(string memory _name, uint _target, uint _start, uint _end) public returns (bool) {
        bytes32 curBytes = head;
        bytes32 nextBytes;
        Provider memory current;
        Provider memory next;

        // remove expired providers
        while (true) {
            current = providerList[curBytes];
            if (curBytes == 0x0 || current.end > now) {
                break;
            }
            curBytes = current.next;
        }
        head = curBytes;

        // validate _end
        require(_end > now, "bad end time");
        require(_start < _end, "bad start time");

        // empty provider list
        if (head == 0x0) {
            bytes32 id = keccak256(abi.encodePacked(_name, _target, _start, _end));
            Provider memory provider = Provider(id, 0x0, _name, _target, _start, _end);
            head = id;
            providerList[id] = provider;
            // logProvider("add provider", provider);
            emit AddProvider(provider.id, provider.next, provider.name, provider.target, provider.start, provider.end);
            return true;
        }

        // loop
        while (true) {
            current = providerList[curBytes];
            nextBytes = current.next;
            next = providerList[nextBytes];
            if (nextBytes == 0x0 || _end <= next.end) {
                // Do insertion when (1) reached the end of the linked list; (2) Or, insert between current and next
                bytes32 id = keccak256(abi.encodePacked(_name, _target, _start, _end));
                current.next = id;
                Provider memory provider = Provider(id, nextBytes, _name, _target, _start, _end);
                providerList[id] = provider;
                // logProvider("add provider", provider);
                emit AddProvider(provider.id, provider.next, provider.name, provider.target, provider.start, provider.end);
                return true;
            }
            curBytes = nextBytes;
        }
        return false;
    }

    function logProvider(string memory msg, Provider memory provider) private {
        log(msg);
        log("id=", provider.id);
        log("next=", provider.next);
        log("name=", provider.name);
        log("target=", provider.target);
        log("start=", provider.start);
        log("end=", provider.end);
    }
}

