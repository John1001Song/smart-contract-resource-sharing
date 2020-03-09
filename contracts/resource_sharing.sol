pragma solidity 0.5.12;

import "./provider.sol";
import "./storager.sol";

contract ResourceSharing is ProviderLib, StorageLib {

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
        string matcher1Name;
        address matcher1Addr;
        string matcher2Name;
        address matcher2Addr;
        string region;
        uint256 price;
        uint matchedTime;
        uint start;
        uint duration;
        address storager1;
        address storager2;
        // uint matchType; // 1: provider+consumer; 2: provider+storager;
    }

    // const
    uint256 public maxMatchInterval;
    string[] regionList;

    // provider, consumer
    mapping(string => bytes32) public headMap; // key="city||mode"
    mapping(address => Matching[]) public matchings;
    mapping(bytes32 => Provider) public providerMap;
    mapping(string => mapping(bytes32 => ProviderIndex)) public providerIndexMap; // key="city||mode"

    // storager
    mapping(string => bytes32) public storageHeadMap;
    mapping(bytes32 => StorageLib.Storager) public storagerMap;

    event AddProvider(bytes32 id, string _name, string _region, address _addr, uint _target, uint _start, uint _end);
    event Matched(string matcher1Name, address matcher1Addr, string matcher2Name, address matcher2Addr, string _region, uint256 price, uint time);

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
        addProviderIndexModeMinLatency(headMap, providerMap, providerIndexMap, id, _region, _start, _end);
        addProviderIndexModeMinCost(headMap, providerMap, providerIndexMap, id, _region, _target, _start, _end);

        // add provider
        Provider memory provider = Provider(id, _name, _region, msg.sender, _target, _start, _end);
        providerMap[id] = provider;
        emit AddProvider(provider.id, provider.name, provider.region, provider.addr, provider.target, provider.start, provider.end);

        return true;
    }

    function addConsumer(string memory _mode, string memory _name, string memory _region, uint _budget, uint _duration, uint _deadline) public returns (bool) {
        require(now + _duration + maxMatchInterval < _deadline, "not enough time to consume resource");

        if (keccak256(bytes(_mode)) != keccak256(bytes("min_latency")) &&
        keccak256(bytes(_mode)) == keccak256(bytes("min_cost"))) {
            return false;
        }
        return addConsumerByMode(_mode, _name, _region, _budget, _duration);
    }


    function addConsumerByMode(string memory _mode, string memory _name, string memory _region, uint _budget, uint _duration) public returns (bool) {
        string[] memory strArr = new string[](3);
        strArr[0] = getProviderKey(_region, _mode);
        strArr[1] = _name;
        strArr[2] = _region;
        /*
            strArr[0] = key;
            strArr[1] = _name;
            strArr[2] = _region;
        */
        uint[] memory uintArr = new uint[](2);
        uintArr[0] = _budget;
        uintArr[1] = _duration;
        /*
            uintArr[0] = _budget;
            uintArr[1] = _duration;
        */

        // remove expired providers
        if (keccak256(bytes(_mode)) != keccak256(bytes("min_latency"))) {
            removeExpiredProvidersModeMinLatency(headMap, providerMap, providerIndexMap, strArr[0]);
        } else if (keccak256(bytes(_mode)) == keccak256(bytes("min_cost"))) {
            removeExpiredProviders(headMap, providerMap, providerIndexMap, strArr[0]);
        }

        if (headMap[strArr[0]] == 0x0) {
            // TODO: if no matching under current region, search adjacent regions
            return false;
        }

        // get head
        Provider memory nextProvider = providerMap[headMap[strArr[0]]];
        ProviderIndex memory curIndex = providerIndexMap[strArr[0]][nextProvider.id];
        ProviderIndex memory nextIndex;


        if (isConsumerMatchProvider(maxMatchInterval, nextProvider.target, uintArr[0], nextProvider.start, nextProvider.end, uintArr[1])) {
            Matching memory m = Matching(nextProvider.name, nextProvider.addr, strArr[1], msg.sender, strArr[2], nextProvider.target, now, nextProvider.start, uintArr[1], nextProvider.addr, address(0));
            matchings[nextProvider.addr].push(m);
            matchings[msg.sender].push(m);
            // emit Matched(nextProvider.name, nextProvider.addr, strArr[1], msg.sender, strArr[2], nextProvider.target, now, stList);

            headMap[strArr[0]] = curIndex.next;
            removeProviderIndices(providerMap, providerIndexMap, strArr[2], nextProvider.id);
            return true;
        }

        // iterate all providers
        while (true) {
            // TODO: if no matching under current region, search adjacent regions
            nextProvider = providerMap[curIndex.next];
            nextIndex = providerIndexMap[strArr[0]][curIndex.next];
            if (curIndex.next == 0x0 || isConsumerMatchProvider(maxMatchInterval, nextProvider.target, uintArr[0], nextProvider.start, nextProvider.end, uintArr[1])) {
                Matching memory m = Matching(nextProvider.name, nextProvider.addr, strArr[1], msg.sender, strArr[2], nextProvider.target, now, nextProvider.start, uintArr[1], nextProvider.addr, address(0));
                matchings[nextProvider.addr].push(m);
                matchings[msg.sender].push(m);
                // emit Matched(nextProvider.name, nextProvider.addr, strArr[1], msg.sender, strArr[2], nextProvider.target, now);

                providerIndexMap[strArr[0]][curIndex.id].next = nextIndex.next;
                removeProviderIndices(providerMap, providerIndexMap, strArr[2], nextIndex.id);
                return true;
            } else {
                curIndex = nextIndex;
            }
        }
        return false;
    }

    function addStorager(string memory _name, string memory _region, uint _size) public returns (bool) {
        return StorageLib.addStorager(storageHeadMap, storagerMap, _name, _region, _size);
    }

    function removeExpiredProvidersModeMinLatency(string memory _key) public {
        removeExpiredProvidersModeMinLatency(headMap, providerMap, providerIndexMap, _key);
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

    struct ProviderIndex {
        bytes32 id;
        bytes32 next;
    }

    /////////////////////////////////////////////////////////// MODE MIN_LATENCY ///////////////////////////////////////////////////////////

    function addProviderIndexModeMinLatency(mapping(string => bytes32) storage headMap,
        mapping(bytes32 => Provider) storage providerMap,
        mapping(string => mapping(bytes32 => ProviderIndex)) storage providerIndexMap,
        bytes32 id, string memory _region, uint _start, uint _end) internal returns (bool) {
        string memory key = getProviderKey(_region, "min_latency");

        // remove expired providers
        removeExpiredProvidersModeMinLatency(headMap, providerMap, providerIndexMap, key);

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
    function removeExpiredProvidersModeMinLatency(mapping(string => bytes32) storage headMap,
        mapping(bytes32 => Provider) storage providerMap,
        mapping(string => mapping(bytes32 => ProviderIndex)) storage providerIndexMap,
        string memory _key) internal {
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

    /////////////////////////////////////////////////////////// MODE MIN_COST ///////////////////////////////////////////////////////////

    function addProviderIndexModeMinCost(mapping(string => bytes32) storage headMap,
        mapping(bytes32 => Provider) storage providerMap,
        mapping(string => mapping(bytes32 => ProviderIndex)) storage providerIndexMap,
        bytes32 id, string memory _region, uint _target, uint _start, uint _end) internal returns (bool) {

        string memory key = getProviderKey(_region, "min_cost");

        Provider memory current = providerMap[headMap[key]];
        Provider memory next;
        ProviderIndex memory curIndex = providerIndexMap[key][headMap[key]];
        ProviderIndex memory newIndex;

        // get first valid provider index, remove expired
        while (true) {
            if (current.id != 0x0) {
                break;
            }
            if (curIndex.id != 0x0) {
                delete (providerIndexMap[key][curIndex.id]);
                headMap[key] = curIndex.next;
                current = providerMap[curIndex.next];
                curIndex = providerIndexMap[key][curIndex.next];
            } else {
                break;
            }
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
            // check next provider is valid
            while (next.id == 0x0 && curIndex.next != 0x0) {
                // link current and next.next
                newIndex = providerIndexMap[key][curIndex.next];
                delete (providerIndexMap[key][newIndex.id]);
                curIndex.next = newIndex.next;
                providerIndexMap[key][curIndex.id] = curIndex;
                next = providerMap[curIndex.next];
            }
            if (curIndex.next == 0x0 || isBetweenCurrentAndNextModeMinCost(next.id, _target, next.target, _start, _end, next.start, next.end)) {
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
        if (_nextBytes == 0x0) {
            return true;
        }
        if (_target > _nextTarget) {
            return false;
        }
        return _end < _nextEnd || (_end == _nextEnd && _start <= _nextStart);
    }

    // Only used for mode MIN_LATENCY
    function removeExpiredProviders(mapping(string => bytes32) storage headMap,
        mapping(bytes32 => Provider) storage providerMap,
        mapping(string => mapping(bytes32 => ProviderIndex)) storage providerIndexMap,
        string memory _key) internal {
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

    /////////////////////////////////////////////////////////// COMMON ///////////////////////////////////////////////////////////

    function getProviderKey(string memory _region, string memory _mode) internal returns (string memory) {
        return stringConcat(_region, "||", _mode);
    }

    function stringConcat(string memory a, string memory b, string memory c) internal pure returns (string memory) {
        return string(abi.encodePacked(a, b, c));
    }

    function removeProviderIndices(mapping(bytes32 => Provider) storage providerMap,
        mapping(string => mapping(bytes32 => ProviderIndex)) storage providerIndexMap,
        string memory _region, bytes32 _id) internal {
        delete (providerMap[_id]);

        // delete indices of all modes
        delete (providerIndexMap[getProviderKey(_region, "min_latency")][_id]);
        delete (providerIndexMap[getProviderKey(_region, "min_cost")][_id]);
    }


    function isConsumerMatchProvider(uint maxMatchInterval, uint proTarget, uint conBudget, uint proStart, uint proEnd, uint conDuration) internal returns (bool) {
        return proTarget <= conBudget && proStart + maxMatchInterval + conDuration < proEnd;
    }
}

