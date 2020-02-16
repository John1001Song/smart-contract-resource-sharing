pragma solidity 0.5.12;

library ProviderLib {
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

    struct ProviderContext {
        mapping(bytes32 => Provider) providerMap;
        mapping(string => bytes32) headMap; // key="city||mode"
        mapping(string => mapping(bytes32 => ProviderIndex)) providerIndexMap; // key="city||mode"
    }

    event EventAddProvider(bytes32 id, string _name, string _region, address _addr, uint _target, uint _start, uint _end);

    function AddProvider(ProviderContext storage self, string memory _name, string memory _region, uint _target, uint _start, uint _end) public returns (bool) {
        require(_end > now, "bad end time");
        require(_start < _end, "bad start time");

        bytes32 id = keccak256(abi.encodePacked(_name, _target, _start, _end, now));

        // add indices
        addProviderIndexModeMinLatency(self, id, _region, _start, _end);
        addProviderIndexModeMinCost(self, id, _region, _target, _start, _end);

        // add provider
        Provider memory provider = Provider(id, _name, _region, msg.sender, _target, _start, _end);
        self.providerMap[id] = provider;
        emit EventAddProvider(provider.id, provider.name, provider.region, provider.addr, provider.target, provider.start, provider.end);

        return true;
    }

    /////////////////////////////////////////////////////////// MODE MIN_LATENCY ///////////////////////////////////////////////////////////

    function addProviderIndexModeMinLatency(ProviderContext storage self, bytes32 id, string memory _region, uint _start, uint _end) public returns (bool) {
        string memory key = GetProviderKey(_region, "min_latency");

        // remove expired providers
        RemoveExpiredProviders(self, key);

        Provider memory current = self.providerMap[self.headMap[key]];
        Provider memory next;
        ProviderIndex memory curIndex;
        ProviderIndex memory newIndex;

        // check head
        if (isBetweenCurrentAndNext(self.headMap[key], _start, _end, current.start, current.end)) {
            newIndex = ProviderIndex(id, current.id);
            self.headMap[key] = id;
            self.providerIndexMap[key][id] = newIndex;
            return true;
        }

        // iterate
        while (true) {
            curIndex = self.providerIndexMap[key][current.id];
            next = self.providerMap[curIndex.next];
            if (isBetweenCurrentAndNext(next.id, _start, _end, next.start, next.end)) {
                newIndex = ProviderIndex(id, curIndex.next);
                self.providerIndexMap[key][id] = newIndex;
                self.providerIndexMap[key][current.id].next = newIndex.id;
                return true;
            }
            current = self.providerMap[curIndex.next];
        }
        return false;
    }

    // Only used for mode MIN_LATENCY
    function RemoveExpiredProviders(ProviderContext storage self, string memory _key) public {
        bytes32 curBytes = self.headMap[_key];
        Provider memory current;
        ProviderIndex memory index;

        while (true) {
            current = self.providerMap[curBytes];
            if (curBytes == 0x0 || current.end > now) {
                break;
            }
            index = self.providerIndexMap[_key][curBytes];
            curBytes = index.next;
            delete (self.providerMap[index.id]);
            delete (self.providerIndexMap[_key][index.id]);
        }
        self.headMap[_key] = curBytes;
    }

    // Only used for mode MIN_LATENCY
    function isBetweenCurrentAndNext(bytes32 _nextBytes, uint _start, uint _end, uint _nextStart, uint _nextEnd) private returns (bool) {
        return _nextBytes == 0x0 || _end < _nextEnd || (_end == _nextEnd && _start <= _nextStart);
    }

    /////////////////////////////////////////////////////////// MODE MIN_COST ///////////////////////////////////////////////////////////

    function addProviderIndexModeMinCost(ProviderContext storage self, bytes32 id, string memory _region, uint _target, uint _start, uint _end) public returns (bool) {
        string memory key = GetProviderKey(_region, "min_cost");

        Provider memory current = self.providerMap[self.headMap[key]];
        Provider memory next;
        ProviderIndex memory curIndex = self.providerIndexMap[key][self.headMap[key]];
        ProviderIndex memory newIndex;

        // get first valid provider index, remove expired
        while (true) {
            if (current.id != 0x0 || curIndex.next == 0x0) {
                break;
            }
            self.headMap[key] = curIndex.next;
            current = self.providerMap[curIndex.next];
            delete (self.providerIndexMap[key][curIndex.id]);
            curIndex = self.providerIndexMap[key][curIndex.next];
        }
        // check first
        if (isBetweenCurrentAndNextModeMinCost(self.headMap[key], _target, current.target, _start, _end, current.start, current.end)) {
            newIndex = ProviderIndex(id, current.id);
            self.headMap[key] = id;
            self.providerIndexMap[key][id] = newIndex;
            return true;
        }

        // iterate
        while (true) {
            curIndex = self.providerIndexMap[key][current.id];
            next = self.providerMap[curIndex.next];
            // check valid and remove expired
            if (next.id == 0x0 && curIndex.next != 0x0) {
                newIndex = self.providerIndexMap[key][next.id];
                delete (self.providerIndexMap[key][newIndex.id]);
                curIndex.next = newIndex.next;
                self.providerIndexMap[key][curIndex.id] = curIndex;
                current = self.providerMap[curIndex.next];
                continue;
            }
            if (isBetweenCurrentAndNextModeMinCost(next.id, _target, next.target, _start, _end, next.start, next.end)) {
                newIndex = ProviderIndex(id, curIndex.next);
                self.providerIndexMap[key][id] = newIndex;
                self.providerIndexMap[key][current.id].next = newIndex.id;
                return true;
            }
            current = self.providerMap[curIndex.next];
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

    /////////////////////////////////////////////////////////// COMMON ///////////////////////////////////////////////////////////

    function GetProviderKey(string memory _region, string memory _mode) public returns (string memory) {
        return stringConcat(_region, "||", _mode);
    }

    function stringConcat(string memory a, string memory b, string memory c) internal pure returns (string memory) {
        return string(abi.encodePacked(a, b, c));
    }

    function RemoveProviderIndices(ProviderContext storage self, string memory _region, bytes32 _id) public {
        delete (self.providerMap[_id]);

        // delete indices of all modes
        delete (self.providerIndexMap[GetProviderKey(_region, "min_latency")][_id]);
        delete (self.providerIndexMap[GetProviderKey(_region, "min_cost")][_id]);
    }

    /////////////////////////////////////////////////////////// INTERFACE ///////////////////////////////////////////////////////////


    function GetHead(ProviderContext storage self, string memory _key) public returns (bytes32){
        return self.headMap[_key];
    }

    function GetProvider(ProviderContext storage self, bytes32 _id) public returns
    (string memory, string memory, address, uint, uint, uint) {
        return (self.providerMap[_id].name, self.providerMap[_id].region, self.providerMap[_id].addr, self.providerMap[_id].target, self.providerMap[_id].start, self.providerMap[_id].end);
    }

    function GetIndex(ProviderContext storage self, string memory _key, bytes32 _id) public returns (bytes32, bytes32) {
        return (self.providerIndexMap[_key][_id].id, self.providerIndexMap[_key][_id].next);
    }

    function SetHeadProvider(ProviderContext storage self, string memory _key, bytes32 _id) public {
        self.headMap[_key] = _id;
    }

    function UpdateProviderIndexNext(ProviderContext storage self, string memory _key, bytes32 _curId, bytes32 _next) public {
        self.providerIndexMap[_key][_curId].next = _next;
    }
}