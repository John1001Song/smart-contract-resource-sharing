pragma solidity 0.5.12;

import "./provider.sol";

contract ResourceSharing {

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
    string[] regionList;
    ProviderLib.ProviderContext providerCtx;

    mapping(address => Matching[]) public matchings;

    event Matched(string providerName, address providerAddr, string consumerName, address consumerAddr, string _region, uint256 price, uint time);

    constructor() public {
        // 100 seconds
        maxMatchInterval = 100 * 1000;

        regionList.push("USA");
        regionList.push("CHINA");
    }

    function addProvider(string memory _name, string memory _region, uint _target, uint _start, uint _end) public returns (bool) {
        return ProviderLib.AddProvider(providerCtx, _name, _region, _target, _start, _end);
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
        string memory key = ProviderLib.GetProviderKey(_region, mode);

        // remove expired providers
        ProviderLib.RemoveExpiredProviders(providerCtx, key);

        string memory nextName;
        address nextAddr;
        bytes32[4] memory indexArr;
        /*
            IndexArr[0] = curIndex.Id;
            IndexArr[1] = curIndex.next;
            IndexArr[2] = nextIndex.Id;
            IndexArr[3] = nextIndex.next;
        */
        uint[3] memory providerUintArr;
        /*
            providerUintArr[0] = provider.target;
            providerUintArr[1] = provider.start;
            providerUintArr[2] = provider.end;
        */

        indexArr[0] = ProviderLib.GetHead(providerCtx, key);
        (nextName, _region, nextAddr, providerUintArr[0], providerUintArr[1], providerUintArr[2]) = ProviderLib.GetProvider(providerCtx, indexArr[0]);
        if (indexArr[0] == 0x0) {
            // TODO: if no matching under current region, search adjacent regions
            return false;
        }

        // check head
        (indexArr[0], indexArr[1]) = ProviderLib.GetIndex(providerCtx, key, indexArr[0]);

        if (isConsumerMatchProvider(providerUintArr[0], _budget, providerUintArr[1], providerUintArr[2], _duration)) {
            Matching memory m = Matching(nextName, nextAddr, _name, msg.sender, _region, providerUintArr[0], now, providerUintArr[1], _duration);
            matchings[nextAddr].push(m);
            matchings[msg.sender].push(m);
            emit Matched(nextName, nextAddr, _name, msg.sender, _region, providerUintArr[0], now);

            ProviderLib.SetHeadProvider(providerCtx, key, indexArr[1]);
            ProviderLib.RemoveProviderIndices(providerCtx, _region, indexArr[0]);
            return true;
        }

        // iterate all providers
        while (true) {
            if (indexArr[1] == 0x0) {
                // TODO: if no matching under current region, search adjacent regions
                return false;
            } else {
                (nextName, _region, nextAddr, providerUintArr[0], providerUintArr[1], providerUintArr[2]) = ProviderLib.GetProvider(providerCtx, indexArr[1]);
                (indexArr[2], indexArr[3]) = ProviderLib.GetIndex(providerCtx, key, indexArr[1]);
            }
            if (isConsumerMatchProvider(providerUintArr[0], _budget, providerUintArr[1], providerUintArr[2], _duration)) {
                Matching memory m = Matching(nextName, nextAddr, _name, msg.sender, _region, providerUintArr[0], now, providerUintArr[1], _duration);
                matchings[nextAddr].push(m);
                matchings[msg.sender].push(m);
                emit Matched(nextName, nextAddr, _name, msg.sender, _region, providerUintArr[0], now);

                ProviderLib.UpdateProviderIndexNext(providerCtx, key, indexArr[0], indexArr[3]);
                ProviderLib.RemoveProviderIndices(providerCtx, _region, indexArr[2]);
                return true;
            } else {
                indexArr[0] = indexArr[2];
                indexArr[1] = indexArr[3];
            }
        }
        return false;
    }

    /////////////////////////////////////////////////////////// COMMON ///////////////////////////////////////////////////////////

    function isConsumerMatchProvider(uint proTarget, uint conBudget, uint proStart, uint proEnd, uint conDuration) private returns (bool) {
        return proTarget <= conBudget && proStart + maxMatchInterval + conDuration < proEnd;
    }
}

