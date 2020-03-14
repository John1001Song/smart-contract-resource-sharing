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

    function addProvider(string memory _mode, string memory _name, string memory _region, uint _target, uint _start, uint _end) public returns (bool) {
        require(_end > now, "bad end time");
        require(_start < _end, "bad start time");

        bytes32 id = keccak256(abi.encodePacked(_name, _target, _start, _end, now));

        if (keccak256(bytes(_mode)) == keccak256(bytes("min_latency"))) {
            addProviderIndexModeMinLatency(headMap, providerMap, providerIndexMap, id, _region, _start, _end);
        } else if (keccak256(bytes(_mode)) == keccak256(bytes("min_cost"))) {
            addProviderIndexModeMinCost(headMap, providerMap, providerIndexMap, id, _region, _target, _start, _end);
        } else {
            return false;
        }

        // add provider
        Provider memory provider = Provider(id, _name, _region, msg.sender, _target, _start, _end);
        providerMap[id] = provider;
        emit AddProvider(provider.id, provider.name, provider.region, provider.addr, provider.target, provider.start, provider.end);

        return true;
    }

    function addConsumer(string memory _mode, string memory _name, string memory _region, uint _budget, uint _duration, uint _deadline) public returns (bool) {
        require(now + _duration + maxMatchInterval < _deadline, "not enough time to consume resource");

        if (keccak256(bytes(_mode)) == keccak256(bytes("min_latency"))) {
            return addConsumerByModeMinLatency(_name, _region, _budget, _duration);
        } else if (keccak256(bytes(_mode)) == keccak256(bytes("min_cost"))) {
            //            return addConsumerByModeMinCost(_mode, _name, _region, _budget, _duration);
            return false;
        }
        return false;
    }


    function addConsumerByModeMinLatency(string memory _name, string memory _region, uint _budget, uint _duration) public returns (bool) {
        string[] memory strArr = new string[](3);
        strArr[0] = getProviderKey(_region, "min_latency");
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
        removeExpiredProvidersModeMinLatency(headMap, providerMap, providerIndexMap, strArr[0]);

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
            delete (providerMap[nextProvider.id]);
            delete (providerIndexMap[strArr[0]][nextProvider.id]);
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
                delete (providerMap[nextIndex.id]);
                delete (providerIndexMap[strArr[0]][nextIndex.id]);
                return true;
            } else {
                curIndex = nextIndex;
                require(1 > 2, "bad");
            }
        }
        return false;
    }

    function addStorager(string memory _name, string memory _region, uint _size) public returns (bool) {
        return StorageLib.addStorager(storageHeadMap, storagerMap, _name, _region, _size);
    }

    function RemoveExpiredProvidersModeMinLatency(string memory _key) public {
        removeExpiredProvidersModeMinLatency(headMap, providerMap, providerIndexMap, _key);
    }


    function isConsumerMatchProvider(uint maxMatchInterval, uint proTarget, uint conBudget, uint proStart, uint proEnd, uint conDuration) internal returns (bool) {
        return proTarget <= conBudget && proStart + maxMatchInterval + conDuration < proEnd;
    }
}

