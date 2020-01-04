pragma solidity 0.5.12;

// copied from https://www.cnblogs.com/huahuayu/p/8593774.html
contract Logger {
    event LogUint(string, uint);
    function log(string memory s, uint x) internal {
        emit LogUint(s, x);
    }
    
    event LogInt(string, int);
    function log(string memory s, int x) internal {
        emit LogInt(s, x);
    }
    
    event LogBytes(string, bytes);
    function log(string memory s, bytes memory x) internal {
        emit LogBytes(s, x);
    }
    
    event LogBytes32(string, bytes32);
    function log(string memory s, bytes32 x) internal {
        emit LogBytes32(s, x);
    }

    event LogAddress(string, address);
    function log(string memory s, address x) internal {
        emit LogAddress(s, x);
    }

    event LogBool(string, bool);
    function log(string memory s, bool x) internal {
        emit LogBool(s, x);
    }
}