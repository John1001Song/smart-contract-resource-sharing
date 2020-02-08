pragma solidity 0.5.12;

import "./logger.sol";

contract ResourceSharing is Logger {

    struct ProviderIndex {
        bytes32 id;
        bytes32 next;
    }

    struct Provider {
        bytes32 id;
        string name;
        string region;
        address addr;
        uint target;
        uint start;
        uint end;
    }

    struct Consumer {
        bytes32 id;
        bytes32 next;

        string name;
        string region;
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
        string region;
        uint256 price;
        uint matchedTime;
        uint start;
        uint duration;
    }

    uint256 public maxMatchInterval;
    bytes32 public head;
    string[] regionList;

    mapping(string => bytes32) public headMap; // key="city||mode"
    mapping(address => Matching[]) public matchings;
    mapping(bytes32 => Provider) public providerMap;
    mapping(string => mapping(bytes32 => ProviderIndex)) public providerIndexMap; // key="city||mode"


    event AddProvider(bytes32 id, string _name, string _region, address _addr, uint _target, uint _start, uint _end);
    event Matched(string providerName, address providerAddr, string consumerName, address consumerAddr, string _region, uint256 price, uint time);

    constructor() public {
        // 100 seconds
        maxMatchInterval = 100 * 1000;

        regionList.push("USA");
        regionList.push("CHINA");
    }

    function addProvider(string memory _name, string memory _region, uint _target, uint _start, uint _end) public returns (bool) {
        require(_end > now, "bad end time");
        require(_start < _end, "bad start time");

        bytes32 id = keccak256(abi.encodePacked(_name, _target, _start, _end, now));

        // add indices
        addProviderIndexModeMinLatency(id, _region, _start, _end);
        // addProviderIndexModeMinCost(id, _region, _start, _end);

        // add provider
        Provider memory provider = Provider(id, _name, _region, msg.sender, _target, _start, _end);
        providerMap[id] = provider;
        emit AddProvider(provider.id, provider.name, provider.region, provider.addr, provider.target, provider.start, provider.end);

        return true;
    }

    function getProviderKey(string memory _region, string memory _mode) private returns (string memory) {
        return stringConcat(_region, "||", _mode);
    }

    function addConsumer(string memory _mode, string memory _name, string memory _region, uint _budget, uint _duration, uint _deadline) public returns (bool) {
        require(now + _duration + maxMatchInterval < _deadline, "not enough time to consume resource");

        if (keccak256(bytes(_mode)) != keccak256(bytes("min_latency")) &&
        keccak256(bytes(_mode)) == keccak256(bytes("min_cost"))) {
            return false;
        }
        return addConsumerByMode(_mode, _name, _region, _budget, _duration);
    }

    /////////////////////////////////////////////////////////// MODE MIN_LATENCY ///////////////////////////////////////////////////////////

    function addProviderIndexModeMinLatency(bytes32 id, string memory _region, uint _start, uint _end) public returns (bool) {
        string memory key = getProviderKey(_region, "min_latency");

        // remove expired providers
        removeExpiredProviders(key);

        Provider memory current = providerMap[headMap[key]];
        Provider memory next;
        ProviderIndex memory curIndex;
        ProviderIndex memory newIndex;

        // check head
        if (isBetweenCurrentAndNext(headMap[key], _start, _end, current.start, current.end)) {
            newIndex = ProviderIndex(id, current.id);
            headMap[key] = id;
            providerIndexMap[key][id] = newIndex;
            return true;
        }

        // iterate
        while (true) {
            curIndex = providerIndexMap[key][current.id];
            next = providerMap[curIndex.next];
            if (isBetweenCurrentAndNext(next.id, _start, _end, next.start, next.end)) {
                newIndex = ProviderIndex(id, curIndex.next);
                providerIndexMap[key][id] = newIndex;
                providerIndexMap[key][current.id].next = newIndex.id;
                return true;
            }
            current = providerMap[curIndex.next];
        }
        return false;
    }

    // Only used for mode MIN_LATENCY
    function removeExpiredProviders(string memory _key) public {
        bytes32 curBytes = headMap[_key];
        Provider memory current;
        ProviderIndex memory index;

        while (true) {
            current = providerMap[curBytes];
            if (curBytes == 0x0 || current.end > now) {
                break;
            }
            index = providerIndexMap[_key][curBytes];
            curBytes = index.next;
            delete (providerMap[index.id]);
            delete (providerIndexMap[_key][index.id]);
        }
        headMap[_key] = curBytes;
    }

    // Only used for mode MIN_LATENCY
    function isBetweenCurrentAndNext(bytes32 _nextBytes, uint _start, uint _end, uint _nextStart, uint _nextEnd) private returns (bool) {
        return _nextBytes == 0x0 || _end < _nextEnd || (_end == _nextEnd && _start <= _nextStart);
    }

    function addConsumerByMode(string memory mode, string memory _name, string memory _region, uint _budget, uint _duration) public returns (bool) {
        string memory key = getProviderKey(_region, mode);

        // remove expired providers
        removeExpiredProviders(key);

        bytes32 head = headMap[key];
        if (head == 0x0) {
            // TODO: if no matching under current region, search adjacent regions
            return false;
        }

        // check head
        Provider memory nextProvider = providerMap[headMap[key]];
        ProviderIndex memory curIndex = providerIndexMap[key][nextProvider.id];
        ProviderIndex memory nextIndex;

        if (isConsumerMatchProvider(nextProvider.target, _budget, nextProvider.start, nextProvider.end, _duration)) {
            Matching memory m = Matching(nextProvider.name, nextProvider.addr, _name, msg.sender, _region, nextProvider.target, now, nextProvider.start, _duration);
            matchings[nextProvider.addr].push(m);
            matchings[msg.sender].push(m);
            emit Matched(nextProvider.name, nextProvider.addr, _name, msg.sender, _region, nextProvider.target, now);

            headMap[key] = curIndex.next;
            removeProviderIndices(_region, nextProvider.id);
            return true;
        }

        // iterate all providers
        Provider memory next;
        while (true) {
            if (curIndex.next == 0x0) {
                // TODO: if no matching under current region, search adjacent regions
                return false;
            } else {
                nextProvider = providerMap[curIndex.next];
                nextIndex = providerIndexMap[key][curIndex.next];
            }
            if (isConsumerMatchProvider(nextProvider.target, _budget, nextProvider.start, nextProvider.end, _duration)) {
                Matching memory m = Matching(nextProvider.name, nextProvider.addr, _name, msg.sender, _region, nextProvider.target, now, nextProvider.start, _duration);
                matchings[nextProvider.addr].push(m);
                matchings[msg.sender].push(m);
                emit Matched(nextProvider.name, nextProvider.addr, _name, msg.sender, _region, nextProvider.target, now);

                providerIndexMap[key][curIndex.id].next = nextIndex.next;
                removeProviderIndices(_region, nextIndex.id);
                return true;
            } else {
                curIndex = nextIndex;
            }
        }
        return false;
    }


    /////////////////////////////////////////////////////////// MODE MIN_COST ///////////////////////////////////////////////////////////

    function addProviderIndexModeMinCost(bytes32 id, string memory _region, uint _target, uint _start, uint _end) public returns (bool) {
        string memory key = getProviderKey(_region, "min_cost");

        Provider memory current = providerMap[headMap[key]];
        Provider memory next;
        ProviderIndex memory curIndex = providerIndexMap[key][headMap[key]];
        ProviderIndex memory newIndex;

        // get first valid provider index, remove expired
        while (true) {
            if (current.id != 0x0 || curIndex.next == 0x0) {
                break;
            }
            headMap[key] = curIndex.next;
            current = providerMap[curIndex.next];
            delete (providerIndexMap[key][curIndex.id]);
            curIndex = providerIndexMap[key][curIndex.next];
        }
        // check first
        if (isBetweenCurrentAndNextModeMinCost(headMap[key], _target, current.target, _start, _end, current.start, current.end)) {
            newIndex = ProviderIndex(id, current.id);
            headMap[key] = id;
            providerIndexMap[key][id] = newIndex;
            return true;
        }

        // iterate
        while (true) {
            curIndex = providerIndexMap[key][current.id];
            next = providerMap[curIndex.next];
            // check valid and remove expired
            if (next.id == 0x0 && curIndex.next != 0x0) {
                newIndex = providerIndexMap[key][next.id];
                delete (providerIndexMap[key][newIndex.id]);
                curIndex.next = newIndex.next;
                providerIndexMap[key][curIndex.id] = curIndex;
                current = providerMap[curIndex.next];
                continue;
            }
            if (isBetweenCurrentAndNextModeMinCost(next.id, _target, next.target, _start, _end, next.start, next.end)) {
                newIndex = ProviderIndex(id, curIndex.next);
                providerIndexMap[key][id] = newIndex;
                providerIndexMap[key][current.id].next = newIndex.id;
                return true;
            }
            current = providerMap[curIndex.next];
        }
        return false;
    }

    function isBetweenCurrentAndNextModeMinCost(bytes32 _nextBytes, uint _target, uint _nextTarget, uint _start, uint _end, uint _nextStart, uint _nextEnd) private returns (bool) {
        return _nextBytes == 0x0 || _target < _nextTarget || _end < _nextEnd || (_end == _nextEnd && _start <= _nextStart);
    }

    /////////////////////////////////////////////////////////// COMMON ///////////////////////////////////////////////////////////

    function isConsumerMatchProvider(uint proTarget, uint conBudget, uint proStart, uint proEnd, uint conDuration) private returns (bool) {
        return proTarget <= conBudget && proStart + maxMatchInterval + conDuration < proEnd;
    }

    function removeProviderIndices(string memory _region, bytes32 _id) private {
        delete (providerMap[_id]);

        // delete indices of all modes
        delete (providerIndexMap[getProviderKey(_region, "min_latency")][_id]);
        delete (providerIndexMap[getProviderKey(_region, "min_cost")][_id]);
    }

    function stringConcat(string memory a, string memory b, string memory c) internal pure returns (string memory) {
        return string(abi.encodePacked(a, b, c));
    }
}

