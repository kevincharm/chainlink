// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {AddressAliasHelper} from "./vendor/arb-bridge-eth/v0.8.0-custom/contracts/libraries/AddressAliasHelper.sol";
import {ForwarderInterface} from "./interfaces/ForwarderInterface.sol";
import {AggregatorInterface} from "../interfaces/AggregatorInterface.sol";
import {AggregatorV3Interface} from "../interfaces/AggregatorV3Interface.sol";
import {AggregatorV2V3Interface} from "../interfaces/AggregatorV2V3Interface.sol";
import {TypeAndVersionInterface} from "../interfaces/TypeAndVersionInterface.sol";
import {FlagsInterface} from "./interfaces/FlagsInterface.sol";
import {ArbitrumSequencerStatusRecorderInterface} from "./interfaces/ArbitrumSequencerStatusRecorderInterface.sol";
import {SimpleReadAccessController} from "../SimpleReadAccessController.sol";
import {ConfirmedOwner} from "../ConfirmedOwner.sol";

/**
 * @title ArbitrumSequencerStatusRecorder - L2 status history aggregator
 * @notice L2 contract that receives status updates from a specific L1 address,
 *  records a new answer if the status changed, and raises or lowers the flag on the
 *   stored Flags contract.
 */
contract ArbitrumSequencerStatusRecorder is
  AggregatorV2V3Interface,
  ArbitrumSequencerStatusRecorderInterface,
  TypeAndVersionInterface,
  SimpleReadAccessController
{
  struct Round {
    bool status;
    uint64 timestamp;
  }

  event Initialized();
  event L1OwnershipTransferred(address indexed from, address indexed to);

  string private constant V3_NO_DATA_ERROR = "No data present";
  /// @dev Follows: https://eips.ethereum.org/EIPS/eip-1967
  address public constant FLAG_ARBITRUM_SEQ_OFFLINE =
    address(bytes20(bytes32(uint256(keccak256("chainlink.flags.arbitrum-seq-offline")) - 1)));

  uint8 public constant override decimals = 0;
  string public constant override description = "L2 Status History";
  uint256 public constant override version = 1;

  /// @dev Flags contract to raise/lower flags on, during status transitions
  FlagsInterface public immutable FLAGS;
  /// @dev L1 address
  address private s_l1Owner;
  /// @dev s_latestRoundId == 0 means this contract is uninitialized.
  uint80 private s_latestRoundId = 0;
  mapping(uint80 => Round) private s_rounds;

  constructor(address flagsAddress, address l1OwnerAddress) {
    setL1Owner(l1OwnerAddress);

    FLAGS = FlagsInterface(flagsAddress);
  }

  /**
   * @notice Initialise the first round. Can't be done in the constructor,
   *    because this contract's address must be permissioned by the the Flags contract
   *    (The Flags contract itself is a SimpleReadAccessController).
   */
  function initialize() external onlyOwner {
    uint80 latestRoundId = s_latestRoundId;
    require(latestRoundId == 0, "Already initialised");

    uint64 timestamp = uint64(block.timestamp);
    bool currentStatus = FLAGS.getFlag(FLAG_ARBITRUM_SEQ_OFFLINE);
    Round memory initialRound = Round(currentStatus, timestamp);
    // Initialise roundId == 1 as the first round
    latestRoundId = 1;
    s_rounds[latestRoundId] = initialRound;
    s_latestRoundId = latestRoundId;

    emit Initialized();
    emit NewRound(latestRoundId, msg.sender, timestamp);
    emit AnswerUpdated(getStatusAnswer(initialRound.status), 0, timestamp);
  }

  /**
   * @notice versions:
   *
   * - Flags 1.0.0: initial release
   *
   * @inheritdoc TypeAndVersionInterface
   */
  function typeAndVersion() external pure virtual override returns (string memory) {
    return "ArbitrumSequencerStatusRecorder 1.0.0";
  }

  /// @return L1 owner address
  function l1Owner() public view virtual returns (address) {
    return s_l1Owner;
  }

  /**
   * @notice transfer ownership of this account to a new L1 owner
   * @dev Forwarding can be disabled by setting the L1 owner as `address(0)`. Accessible only by owner.
   * @param to new L1 owner that will be allowed to call the forward fn
   */
  function transferL1Ownership(address to) external virtual onlyOwner {
    setL1Owner(to);
  }

  /// @notice internal method that stores the L1 owner
  function setL1Owner(address to) private {
    address from = s_l1Owner;
    if (from != to) {
      s_l1Owner = to;
      emit L1OwnershipTransferred(from, to);
    }
  }

  /**
   * @dev Returns an AggregatorV2V3Interface compatible answer from status flag
   */
  function getStatusAnswer(bool stat) private pure returns (int256) {
    return stat ? int256(1) : int256(0);
  }

  /**
   * @notice The L2 xDomain `msg.sender`, generated from L1 sender address
   */
  function crossDomainMessenger() public view returns (address) {
    return AddressAliasHelper.applyL1ToL2Alias(l1Owner());
  }

  /**
   * @notice Raise or lower the flag on the stored Flags contract.
   */
  function forwardStatusToFlags(bool status) private {
    if (status) {
      FLAGS.raiseFlag(FLAG_ARBITRUM_SEQ_OFFLINE);
    } else {
      FLAGS.lowerFlag(FLAG_ARBITRUM_SEQ_OFFLINE);
    }
  }

  /**
   * @notice Record a new status and timestamp if it has changed since the last round.
   */
  function updateStatus(bool status, uint64 timestamp) external override {
    uint80 latestRoundId = s_latestRoundId;
    require(latestRoundId > 0, "ArbitrumSequencerStatusRecorder has not been initialized");
    require(msg.sender == crossDomainMessenger(), "Sender is not the L2 messenger");

    // Ignore if status did not change
    if (status == s_rounds[latestRoundId].status) {
      return;
    }

    // Prepare & load a new round with updated status
    Round memory nextRound = Round(status, timestamp);
    latestRoundId += 1;
    s_rounds[latestRoundId] = nextRound;
    s_latestRoundId = latestRoundId;

    emit NewRound(latestRoundId, msg.sender, timestamp);
    emit AnswerUpdated(getStatusAnswer(nextRound.status), latestRoundId, timestamp);

    forwardStatusToFlags(status);
  }

  /// @inheritdoc AggregatorInterface
  function latestAnswer() external view override checkAccess returns (int256) {
    uint80 latestRoundId = s_latestRoundId;
    require(latestRoundId > 0, "ArbitrumSequencerStatusRecorder has not been initialized");
    return getStatusAnswer(s_rounds[latestRoundId].status);
  }

  /// @inheritdoc AggregatorInterface
  function latestTimestamp() external view override checkAccess returns (uint256) {
    uint80 latestRoundId = s_latestRoundId;
    require(latestRoundId > 0, "ArbitrumSequencerStatusRecorder has not been initialized");
    return s_rounds[latestRoundId].timestamp;
  }

  /// @inheritdoc AggregatorInterface
  function latestRound() external view override checkAccess returns (uint256) {
    uint80 latestRoundId = s_latestRoundId;
    require(latestRoundId > 0, "ArbitrumSequencerStatusRecorder has not been initialized");
    return latestRoundId;
  }

  /// @inheritdoc AggregatorInterface
  function getAnswer(uint256 roundId) external view override checkAccess returns (int256) {
    uint80 latestRoundId = s_latestRoundId;
    require(latestRoundId > 0, "ArbitrumSequencerStatusRecorder has not been initialized");
    if (roundId > 0 && roundId <= type(uint80).max && latestRoundId >= roundId) {
      return getStatusAnswer(s_rounds[uint80(roundId)].status);
    }

    return 0;
  }

  /// @inheritdoc AggregatorInterface
  function getTimestamp(uint256 roundId) external view override checkAccess returns (uint256) {
    uint80 latestRoundId = s_latestRoundId;
    require(latestRoundId > 0, "ArbitrumSequencerStatusRecorder has not been initialized");
    if (roundId > 0 && roundId <= type(uint80).max && latestRoundId >= roundId) {
      return s_rounds[uint80(roundId)].timestamp;
    }

    return 0;
  }

  /// @inheritdoc AggregatorV3Interface
  function getRoundData(uint80 _roundId)
    public
    view
    override
    checkAccess
    returns (
      uint80 roundId,
      int256 answer,
      uint256 startedAt,
      uint256 updatedAt,
      uint80 answeredInRound
    )
  {
    uint80 latestRoundId = s_latestRoundId;
    require(_roundId > 0 && latestRoundId > 0 && latestRoundId >= _roundId, "No data present");

    Round memory r = s_rounds[_roundId];
    roundId = _roundId;
    answer = getStatusAnswer(r.status);
    startedAt = uint256(r.timestamp);
    updatedAt = startedAt;
    answeredInRound = _roundId;
  }

  /// @inheritdoc AggregatorV3Interface
  function latestRoundData()
    external
    view
    override
    checkAccess
    returns (
      uint80 roundId,
      int256 answer,
      uint256 startedAt,
      uint256 updatedAt,
      uint80 answeredInRound
    )
  {
    return getRoundData(s_latestRoundId);
  }
}
