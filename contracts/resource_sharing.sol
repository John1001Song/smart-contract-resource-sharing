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
    mapping(bytes32 => Provider) public providerList;
    mapping(address => Matching[]) public matchings;

    event AddProvider(bytes32 id, bytes32 next, string _name, address _addr, uint _target, uint _start, uint _end);
    event Matched(string providerName, address providerAddr, string consumerName, address consumerAddr, uint256 price, uint time, uint start, uint duration);

    constructor() public {
        // 100 seconds
        maxMatchInterval = 100 * 1000;
    }

    // ALERT: delete this method before deploying contract on the main chain!!!!!
    function reset() public {
        head = 0x0;
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

        // Do insertion at head when (1) empty provider list; (2) Or, _end < first end; (3) Or, _end == firest end && _start >= first start
        if (isBetweenCurrentAndNext(head, _start, _end, current.start, current.end)) {
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
            if (isBetweenCurrentAndNext(nextBytes, _start, _end, next.start, next.end)) {
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

    function isBetweenCurrentAndNext(bytes32 _nextBytes, uint _start, uint _end, uint _nextStart, uint _nextEnd) private returns (bool) {
        return _nextBytes == 0x0 || _end < _nextEnd || (_end == _nextEnd && _start <= _nextStart);
    }

    function addConsumer(string memory _name, uint _budget, uint _duration, uint _deadline) public returns (bool) {
        require(now + _duration + maxMatchInterval < _deadline, "not enough time to consume resource");

        // remove expired providers
        removeExpiredProviders();
        if (head == 0x0) {
            return false;
        }

        Provider memory current = providerList[head];

        // check head
        if (isConsumerMatchProvider(current.target, _budget, current.start, current.end, _duration)) {
            Matching memory m = Matching(current.name, current.addr, _name, msg.sender, current.target, now, current.start, _duration);
            matchings[current.addr].push(m);
            matchings[msg.sender].push(m);
            emit Matched(current.name, current.addr, _name, msg.sender, current.target, now, current.start, _duration);

            head = current.next;
            return true;
        }

        // iterate all providers
        Provider memory next;
        while (true) {
            if (current.next == 0x0) {
                return false;
            }
            next = providerList[current.next];
            if (isConsumerMatchProvider(next.target, _budget, next.start, next.end, _duration)) {
                // matched
                Matching memory m = Matching(next.name, next.addr, _name, msg.sender, next.target, now, next.start, _duration);
                matchings[next.addr].push(m);
                matchings[msg.sender].push(m);
                emit Matched(next.name, next.addr, _name, msg.sender, next.target, now, next.start, _duration);

                /*
                // increase provider's start
                provider.start += maxMatchInterval + _duration;
                providerList[provider.id] = provider;

                // TODO: do deletion and insertion here to save gas
                removeProvider(provider.id);
                if (provider.start < provider.end) {
                    addProvider(provider.name, provider.target, provider.start, provider.end);
                }
                */

                // TODO: if needed, increase start and insert again
                delete (providerList[current.next]);
                current.next = next.next;
                return true;
            }
            current = next;
        }
        return false;
    }

    function isConsumerMatchProvider(uint proTarget, uint conBudget, uint proStart, uint proEnd, uint conDuration) private returns (bool) {
        return proTarget <= conBudget && proStart + maxMatchInterval + conDuration < proEnd;
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

    function removeProvider(bytes32 _id) private {
        if (head == 0x0) {
            return;
        }
        bytes32 curBytes = head;
        Provider memory current = providerList[head];
        Provider memory target = providerList[_id];

        if (head == _id) {
            head = current.next;
            return;
        }

        while (curBytes != 0x0) {
            current = providerList[curBytes];
            if (current.next == _id) {
                current.next = target.next;
                providerList[curBytes] = current;
                break;
            }
            curBytes = current.next;
        }
    }
}
