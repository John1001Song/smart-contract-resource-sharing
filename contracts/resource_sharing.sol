pragma solidity 0.5.12;

import "./logger.sol";

contract ResourceSharing is Logger {

    struct Provider {
        bytes32 id;
        bytes32 next;

        string name;
        address addr;
        uint target;
        uint start;
        uint end;
    }

    struct Consumer {
        bytes32 id;
        bytes32 next;

        string name;
        address addr;
        uint budget;
        uint duration;
        uint deadline;
    }

    struct Matching {
        string providerName;
        address providerAddr;
        string consumerName;
        address consumerAddr;
        uint256 price;
        uint matchedTime;
        uint start;
        uint duration;
    }

    uint256 public maxMatchInterval;
    bytes32 public head;
    mapping (bytes32 => Provider) public providerList;
    mapping (address => Matching) public matchings;

    event AddProvider(bytes32 id, bytes32 next, string _name, address _addr, uint _target, uint _start, uint _end);
    event Matched(string providerName, address providerAddr, string consumerName, address consumerAddr, uint256 price, uint time, uint start, uint duration);

    constructor() public {
        // 100 seconds
        maxMatchInterval = 100 * 1000;
    }

    function addProvider(string memory _name, uint _target, uint _start, uint _end) public returns (bool) {
        require(_end > now, "bad end time");
        require(_start < _end, "bad start time");

        // remove expired providers
        removeExpiredProviders();

        bytes32 curBytes = head;
        bytes32 nextBytes;
        Provider memory current = providerList[head];
        Provider memory next;
        bytes32 id = keccak256(abi.encodePacked(_name, _target, _start, _end, now));

        // Do insertion at head when (1) empty provider list; (2) Or, _end <= first end
        if (head == 0x0 || _end <= current.end) {
            Provider memory provider = Provider(id, current.id, _name, msg.sender, _target, _start, _end);
            head = id;
            providerList[id] = provider;
            // logProvider("add provider", provider);
            emit AddProvider(provider.id, provider.next, provider.name, provider.addr, provider.target, provider.start, provider.end);
            return true;
        }

        // loop
        while (true) {
            current = providerList[curBytes];
            nextBytes = current.next;
            next = providerList[nextBytes];
            if (nextBytes == 0x0 || _end <= next.end) {
                // Do insertion when (1) reached the end of the linked list; (2) Or, insert between current and next
                current.next = id;
                providerList[curBytes] = current;
                Provider memory provider = Provider(id, nextBytes, _name, msg.sender, _target, _start, _end);
                providerList[id] = provider;
                // logProvider("add provider", provider);
                emit AddProvider(provider.id, provider.next, provider.name, provider.addr, provider.target, provider.start, provider.end);
                return true;
            }
            curBytes = nextBytes;
        }
        return false;
    }

    function addConsumer(string memory _name, uint _budget, uint _duration, uint _deadline) public returns (bool) {
        require(now + _duration + maxMatchInterval < _deadline, "not enough time to consume resource");
        
        // remove expired providers
        removeExpiredProviders();

        bytes32 curBytes = head;
        Provider memory provider;
        while (true) {
            if (curBytes == 0x0) {
                break;
            }
            provider = providerList[curBytes];
            if (provider.target < _budget) {
                curBytes = provider.next;
                continue;
            }
            if (provider.start + maxMatchInterval + _duration < provider.end ) {
                // matched
                Matching memory m = Matching(provider.name, provider.addr, _name, msg.sender, _budget, now, provider.start, _duration);
                matchings[provider.addr] = m;
                matchings[msg.sender] = m;
                emit Matched(provider.name, provider.addr, _name, msg.sender, _budget, now, provider.start, _duration);

                // increase provider's start
                // TODO: if new start > end, remove provider
                provider.start += maxMatchInterval + _duration;
                providerList[provider.id] = provider;
                return true;
            } else {
                curBytes = provider.next;
            }
        }
        return false;
    }

    function removeExpiredProviders() public {
        bytes32 curBytes = head;
        Provider memory current = providerList[head];

        while (true) {
            current = providerList[curBytes];
            if (curBytes == 0x0 || current.end > now) {
                break;
            }
            curBytes = current.next;
        }
        head = curBytes;
    }

    function logProvider(string memory msg, Provider memory provider) private {
        log(msg);
        log("id=", provider.id);
        log("next=", provider.next);
        log("name=", provider.name);
        log("address=", provider.addr);
        log("target=", provider.target);
        log("start=", provider.start);
        log("end=", provider.end);
    }
}

