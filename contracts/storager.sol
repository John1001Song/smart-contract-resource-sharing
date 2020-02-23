pragma solidity 0.5.12;

contract StorageLib {

    struct Storager {
        bytes32 id;
        bytes32 next;

        string name;
        address addr;
        uint size; // MB
    }

    function addStorager(mapping(string => bytes32) storage headMap,
        mapping(bytes32 => Storager) storage storagerMap,
        string memory _name, string memory _region, uint _size) internal returns (bool) {

        bytes32 id = keccak256(abi.encodePacked(_name, _size, now));

        Storager memory current = storagerMap[headMap[_region]];
        Storager memory next;

        // check head
        if (isBetweenCurrentAndNext(current.id, _size, current.size)) {
            next = Storager(id, current.id, _name, msg.sender, _size);
            storagerMap[id] = next;
            headMap[_region] = id;
            return true;
        }

        while (true) {
            next = storagerMap[current.next];
            if (isBetweenCurrentAndNext(next.id, _size, next.size)) {
                Storager memory storager = Storager(id, next.id, _name, msg.sender, _size);
                current.next = storager.id;
                storagerMap[current.id] = current;
                storagerMap[storager.id] = storager;
                return true;
            }
            current = next;
        }
        return false;
    }

    function isBetweenCurrentAndNext(bytes32 _nextId, uint _size, uint _nextSize) private returns (bool) {
        return _nextId == 0x0 || _size <= _nextSize;
    }
}
