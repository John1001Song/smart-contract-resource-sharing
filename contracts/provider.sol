pragma solidity 0.5.12;

contract ProviderLib {
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

        Provider memory next = providerMap[headMap[key]];
        ProviderIndex memory curIndex = providerIndexMap[key][next.id];
        ProviderIndex memory newIndex;

        // remove expired heads
        while (true) {
            if (next.id == 0x0) {
                break;
            }
            if (next.end <= now) {
                // expire
                delete (providerMap[next.id]);
                delete (providerIndexMap[key][next.id]);
                headMap[key] = curIndex.next;
                curIndex = providerIndexMap[key][curIndex.next];
                next = providerMap[curIndex.id];
            } else {
                break;
            }

        }
        if (isBetweenCurrentAndNextModeMinCost(headMap[key], _target, next.target, _start, _end, next.start, next.end)) {
            newIndex = ProviderIndex(id, next.id);
            headMap[key] = id;
            providerIndexMap[key][id] = newIndex;
            return true;
        }

        // iterate
        while (true) {
            newIndex = providerIndexMap[key][curIndex.next];
            next = providerMap[curIndex.next];
            // check next provider is valid
            if (next.id != 0x0 && next.end <= now) {
                // expire
                delete (providerMap[newIndex.id]);
                delete (providerIndexMap[key][newIndex.id]);
                curIndex.next = newIndex.next;
                providerIndexMap[key][curIndex.id] = curIndex;
                curIndex = newIndex;
            } else if (curIndex.next == 0x0 || isBetweenCurrentAndNextModeMinCost(next.id, _target, next.target, _start, _end, next.start, next.end)) {
                newIndex = ProviderIndex(id, curIndex.next);
                providerIndexMap[key][id] = newIndex;
                curIndex.next = id;
                providerIndexMap[key][curIndex.id] = curIndex;
                return true;
            }
            curIndex = newIndex;
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
}
