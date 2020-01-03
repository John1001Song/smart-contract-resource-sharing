pragma solidity 0.5.12;

contract Election {
    // Read/write candidate
    string public candidate;

    struct Candidate {
        uint id;
        string name;
        uint voteCount;
    }

    mapping(uint => Candidate) public candidates;
    mapping(address => bool) public voters;

    uint public candidatesCount;

    // Constructor
    constructor() public {
        addCandidate("Candidate 1");
        addCandidate("Candidate 2");
    }

    function addCandidate (string memory _name) private {
        candidatesCount++;
        candidates[candidatesCount] = Candidate(candidatesCount, _name, 0);
    }

    function vote (uint _candidateId) public {
        require(!voters[msg.sender], "candidate has voted before");
        require(_candidateId > 0 && _candidateId <= candidatesCount, "bad candidate id");

        voters[msg.sender] = true;
        candidates[_candidateId].voteCount += 1;

        emit votedEvent(_candidateId);
    }

    function deVote (uint _candidateId) public {
        voters[msg.sender] = false;
        candidates[_candidateId].voteCount -= 1;
    }

    event votedEvent (
        uint indexed _candidateId
    );
}