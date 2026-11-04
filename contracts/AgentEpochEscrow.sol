// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title AgentEpochEscrow
 * @dev 24-Hour Asynchronous Algorithmic Portfolio Arena for AI Agents.
 *      Agents submit encrypted asset allocation vectors once per epoch.
 *      10.00% automated house rake sent to house fee recipient.
 */
interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

contract AgentEpochEscrow {
    address public immutable houseFeeRecipient;
    uint256 public constant HOUSE_RAKE_BPS = 1000; // 10.00%
    uint256 public constant BPS_DENOMINATOR = 10000;
    uint256 public constant EPOCH_DURATION = 86400; // 24 hours

    struct Epoch {
        uint256 epochId;
        uint256 startTime;
        uint256 commitEndTime;
        uint256 resolutionTime;
        uint256 entryStake;
        uint256 totalPot;
        uint256 participantCount;
        bool resolved;
        address winner;
    }

    uint256 public currentEpochId;
    mapping(uint256 => Epoch) public epochs;
    mapping(uint256 => mapping(address => bytes32)) public commitments; // epochId => agent => hash

    event EpochStarted(uint256 indexed epochId, uint256 entryStake, uint256 commitEndTime, uint256 resolutionTime);
    event AllocationCommitted(uint256 indexed epochId, address indexed agent, bytes32 commitHash);
    event EpochSettled(uint256 indexed epochId, address indexed winner, uint256 prize, uint256 houseRake);

    constructor(address _houseFeeRecipient) {
        require(_houseFeeRecipient != address(0), "Invalid recipient");
        houseFeeRecipient = _houseFeeRecipient;
    }

    function startNewEpoch(uint256 entryStake) external returns (uint256) {
        require(entryStake > 0, "Stake must be > 0");
        uint256 eid = ++currentEpochId;
        uint256 nowTs = block.timestamp;

        epochs[eid] = Epoch({
            epochId: eid,
            startTime: nowTs,
            commitEndTime: nowTs + 72000, // 20 hour window to commit
            resolutionTime: nowTs + EPOCH_DURATION, // 24 hour mark
            entryStake: entryStake,
            totalPot: 0,
            participantCount: 0,
            resolved: false,
            winner: address(0)
        });

        emit EpochStarted(eid, entryStake, nowTs + 72000, nowTs + EPOCH_DURATION);
        return eid;
    }

    function commitAllocation(uint256 epochId, bytes32 allocationHash, address token) external payable {
        Epoch storage ep = epochs[epochId];
        require(block.timestamp <= ep.commitEndTime, "Commit window closed");
        require(commitments[epochId][msg.sender] == bytes32(0), "Already committed");

        if (token == address(0)) {
            require(msg.value == ep.entryStake, "Native stake mismatch");
        } else {
            require(IERC20(token).transferFrom(msg.sender, address(this), ep.entryStake), "Transfer failed");
        }

        commitments[epochId][msg.sender] = allocationHash;
        ep.totalPot += ep.entryStake;
        ep.participantCount += 1;

        emit AllocationCommitted(epochId, msg.sender, allocationHash);
    }

    function settleEpoch(uint256 epochId, address winner, address token) external {
        Epoch storage ep = epochs[epochId];
        require(block.timestamp >= ep.resolutionTime, "Epoch still running");
        require(!ep.resolved, "Already settled");
        require(ep.participantCount > 0, "No participants");

        ep.resolved = true;
        ep.winner = winner;

        uint256 houseRake = (ep.totalPot * HOUSE_RAKE_BPS) / BPS_DENOMINATOR;
        uint256 prize = ep.totalPot - houseRake;

        if (token == address(0)) {
            payable(houseFeeRecipient).transfer(houseRake);
            payable(winner).transfer(prize);
        } else {
            IERC20(token).transfer(houseFeeRecipient, houseRake);
            IERC20(token).transfer(winner, prize);
        }

        emit EpochSettled(epochId, winner, prize, houseRake);
    }
}
