pragma solidity 0.5.12;

import "./provider.sol";

contract ResourceSharing is ProviderLib {

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

    struct Storager {
        bytes32 id;

        string name;
        string region;
        address addr;
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
        uint matchType; // 1: provider+consumer; 2: provider+storager;
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
    mapping(bytes32 => Storager) public storagerMap;

    event AddProvider(bytes32 id, string _name, string _region, address _addr, uint _target, uint _start, uint _end);
    event Matched(string matcher1Name, address matcher1Addr, string matcher2Name, address matcher2Addr, string _region, uint256 price, uint time, uint matchType);

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
        ProviderLib.Provider memory provider = Provider(id, _name, _region, msg.sender, _target, _start, _end);
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


    function addConsumerByMode(string memory mode, string memory _name, string memory _region, uint _budget, uint _duration) public returns (bool) {
        string memory key = getProviderKey(_region, mode);

        // remove expired providers
        removeExpiredProviders(headMap, providerMap, providerIndexMap, key);

        bytes32 head = headMap[key];
        if (head == 0x0) {
            // TODO: if no matching under current region, search adjacent regions
            return false;
        }

        // check head
        ProviderLib.Provider memory nextProvider = providerMap[headMap[key]];
        ProviderLib.ProviderIndex memory curIndex = providerIndexMap[key][nextProvider.id];
        ProviderLib.ProviderIndex memory nextIndex;

        if (isConsumerMatchProvider(maxMatchInterval, nextProvider.target, _budget, nextProvider.start, nextProvider.end, _duration)) {
            Matching memory m = Matching(nextProvider.name, nextProvider.addr, _name, msg.sender, _region, nextProvider.target, now, nextProvider.start, _duration, 1);
            matchings[nextProvider.addr].push(m);
            matchings[msg.sender].push(m);
            emit Matched(nextProvider.name, nextProvider.addr, _name, msg.sender, _region, nextProvider.target, now, 1);

            headMap[key] = curIndex.next;
            removeProviderIndices(providerMap, providerIndexMap, _region, nextProvider.id);
            return true;
        }

        // iterate all providers
        ProviderLib.Provider memory next;
        while (true) {
            // TODO: if no matching under current region, search adjacent regions
            nextProvider = providerMap[curIndex.next];
            nextIndex = providerIndexMap[key][curIndex.next];
            if (curIndex.next == 0x0 || isConsumerMatchProvider(maxMatchInterval, nextProvider.target, _budget, nextProvider.start, nextProvider.end, _duration)) {
                Matching memory m = Matching(nextProvider.name, nextProvider.addr, _name, msg.sender, _region, nextProvider.target, now, nextProvider.start, _duration, 1);
                matchings[nextProvider.addr].push(m);
                matchings[msg.sender].push(m);
                emit Matched(nextProvider.name, nextProvider.addr, _name, msg.sender, _region, nextProvider.target, now, 1);

                providerIndexMap[key][curIndex.id].next = nextIndex.next;
                removeProviderIndices(providerMap, providerIndexMap, _region, nextIndex.id);
                return true;
            } else {
                curIndex = nextIndex;
            }
        }
        return false;
    }




    /////////////////////////////////////////////////////////// STORAGER ///////////////////////////////////////////////////////////


}

