// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {AddressAliasHelper} from "./vendor/arb-bridge-eth/v0.8.0-custom/contracts/libraries/AddressAliasHelper.sol";
import {ForwarderInterface} from "./interfaces/ForwarderInterface.sol";
import {AggregatorInterface} from "../interfaces/AggregatorInterface.sol";
import {AggregatorV3Interface} from "../interfaces/AggregatorV3Interface.sol";
import {AggregatorV2V3Interface} from "../interfaces/AggregatorV2V3Interface.sol";
import {TypeAndVersionInterface} from "../interfaces/TypeAndVersionInterface.sol";
import {FlagsInterface} from "./interfaces/FlagsInterface.sol";
import {ArbitrumSequencerUptimeFeedInterface} from "./interfaces/ArbitrumSequencerUptimeFeedInterface.sol";
import {SimpleReadAccessController} from "../SimpleReadAccessController.sol";
import {ConfirmedOwner} from "../ConfirmedOwner.sol";

/**
 * @title ArbitrumSequencerUptimeFeed - L2 sequencer uptime status aggregator
 * @notice L2 contract that receives status updates from a specific L1 address,
 *  records a new answer if the status changed, and raises or lowers the flag on the
 *   stored Flags contract.
 */
contract ArbitrumSequencerUptimeFeed is
  AggregatorV2V3Interface,
  ArbitrumSequencerUptimeFeedInterface,
  TypeAndVersionInterface,
  SimpleReadAccessController
{
  /// @dev Round info (for uptime history)
  struct Round {
    int256 answer;
    uint64 timestamp;
  }

  /// @dev Packed state struct to save sloads
  struct FeedState {
    uint80 latestRoundId;
    int256 latestAnswer;
    uint64 latestTimestamp;
  }

  event Initialized();
  event L1SenderTransferred(address indexed from, address indexed to);

  string private constant V3_NO_DATA_ERROR = "No data present";
  /// @dev Follows: https://eips.ethereum.org/EIPS/eip-1967
  address public constant FLAG_L2_SEQ_OFFLINE =
    address(bytes20(bytes32(uint256(keccak256("chainlink.flags.l2-seq-offline")) - 1)));

  uint8 public constant override decimals = 0;
  string public constant override description = "L2 Sequencer Uptime Status Feed";
  uint256 public constant override version = 1;

  /// @dev Flags contract to raise/lower flags on, during status transitions
  FlagsInterface public immutable FLAGS;
  /// @dev L1 address
  address private s_l1Sender;
  /// @dev s_latestRoundId == 0 means this contract is uninitialized.
  FeedState private s_feedState = FeedState({latestRoundId: 0, latestAnswer: 0, latestTimestamp: 0});
  mapping(uint80 => Round) private s_rounds;

  constructor(address flagsAddress, address l1SenderAddress) {
    setL1Sender(l1SenderAddress);

    FLAGS = FlagsInterface(flagsAddress);
  }

  /**
   * @notice Initialise the first round. Can't be done in the constructor,
   *    because this contract's address must be permissioned by the the Flags contract
   *    (The Flags contract itself is a SimpleReadAccessController).
   */
  function initialize() external onlyOwner {
    FeedState memory feedState = s_feedState;
    require(feedState.latestRoundId == 0, "Already initialised");

    uint64 timestamp = uint64(block.timestamp);
    int256 currentAnswer = getStatusAnswer(FLAGS.getFlag(FLAG_L2_SEQ_OFFLINE));

    // Initialise roundId == 1 as the first round
    feedState.latestRoundId += 1;
    feedState.latestAnswer = currentAnswer;
    feedState.latestTimestamp = timestamp;
    // Create initial round
    Round memory initialRound = Round(currentAnswer, timestamp);
    s_rounds[feedState.latestRoundId] = initialRound;
    // Update the current feed state
    s_feedState = feedState;

    emit Initialized();
    emit NewRound(feedState.latestRoundId, msg.sender, timestamp);
    emit AnswerUpdated(initialRound.answer, 0, timestamp);
  }

  /**
   * @notice versions:
   *
   * - Flags 1.0.0: initial release
   *
   * @inheritdoc TypeAndVersionInterface
   */
  function typeAndVersion() external pure virtual override returns (string memory) {
    return "ArbitrumSequencerUptimeFeed 1.0.0";
  }

  /// @return L1 sender address
  function l1Sender() public view virtual returns (address) {
    return s_l1Sender;
  }

  /**
   * @notice Set the allowed L1 sender for this contract to a new L1 sender
   * @dev Can be disabled by setting the L1 sender as `address(0)`. Accessible only by owner.
   * @param to new L1 sender that will be allowed to call `updateStatus` on this contract
   */
  function transferL1Sender(address to) external virtual onlyOwner {
    setL1Sender(to);
  }

  /// @notice internal method that stores the L1 sender
  function setL1Sender(address to) private {
    address from = s_l1Sender;
    if (from != to) {
      s_l1Sender = to;
      emit L1SenderTransferred(from, to);
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
    return AddressAliasHelper.applyL1ToL2Alias(l1Sender());
  }

  /**
   * @notice Raise or lower the flag on the stored Flags contract.
   */
  function forwardStatusToFlags(bool status) private {
    if (status) {
      FLAGS.raiseFlag(FLAG_L2_SEQ_OFFLINE);
    } else {
      FLAGS.lowerFlag(FLAG_L2_SEQ_OFFLINE);
    }
  }

  /**
   * @notice Record a new status and timestamp if it has changed since the last round.
   */
  function updateStatus(bool status, uint64 timestamp) external override {
    FeedState memory feedState = s_feedState;
    require(feedState.latestRoundId > 0, "ArbitrumSequencerUptimeFeed has not been initialized");
    require(msg.sender == crossDomainMessenger(), "Sender is not the L2 messenger");

    // Ignore if status did not change
    int256 newAnswer = getStatusAnswer(status);
    if (feedState.latestAnswer == newAnswer) {
      return;
    }

    // Prepare a new round with updated status
    feedState.latestRoundId += 1;
    feedState.latestAnswer = newAnswer;
    feedState.latestTimestamp = timestamp;
    Round memory nextRound = Round(newAnswer, timestamp);
    // Set all storage variables
    s_rounds[feedState.latestRoundId] = nextRound;
    s_feedState = feedState;

    emit NewRound(feedState.latestRoundId, msg.sender, timestamp);
    emit AnswerUpdated(nextRound.answer, feedState.latestRoundId, timestamp);

    forwardStatusToFlags(status);
  }

  /// @inheritdoc AggregatorInterface
  function latestAnswer() external view override checkAccess returns (int256) {
    FeedState memory feedState = s_feedState;
    require(feedState.latestRoundId > 0, "ArbitrumSequencerUptimeFeed has not been initialized");
    return feedState.latestAnswer;
  }

  /// @inheritdoc AggregatorInterface
  function latestTimestamp() external view override checkAccess returns (uint256) {
    FeedState memory feedState = s_feedState;
    require(feedState.latestRoundId > 0, "ArbitrumSequencerUptimeFeed has not been initialized");
    return s_rounds[feedState.latestRoundId].timestamp;
  }

  /// @inheritdoc AggregatorInterface
  function latestRound() external view override checkAccess returns (uint256) {
    FeedState memory feedState = s_feedState;
    require(feedState.latestRoundId > 0, "ArbitrumSequencerUptimeFeed has not been initialized");
    return feedState.latestRoundId;
  }

  /// @inheritdoc AggregatorInterface
  function getAnswer(uint256 roundId) external view override checkAccess returns (int256) {
    FeedState memory feedState = s_feedState;
    require(feedState.latestRoundId > 0, "ArbitrumSequencerUptimeFeed has not been initialized");
    if (roundId > 0 && roundId <= type(uint80).max && feedState.latestRoundId >= roundId) {
      return s_rounds[uint80(roundId)].answer;
    }

    return 0;
  }

  /// @inheritdoc AggregatorInterface
  function getTimestamp(uint256 roundId) external view override checkAccess returns (uint256) {
    FeedState memory feedState = s_feedState;
    require(feedState.latestRoundId > 0, "ArbitrumSequencerUptimeFeed has not been initialized");
    if (roundId > 0 && roundId <= type(uint80).max && feedState.latestRoundId >= roundId) {
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
    FeedState memory feedState = s_feedState;
    require(_roundId > 0 && feedState.latestRoundId > 0 && feedState.latestRoundId >= _roundId, "No data present");

    Round memory r = s_rounds[_roundId];
    roundId = _roundId;
    answer = r.answer;
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
    FeedState memory feedState = s_feedState;
    require(feedState.latestRoundId > 0, "No data present");

    roundId = feedState.latestRoundId;
    answer = feedState.latestAnswer;
    startedAt = feedState.latestTimestamp;
    updatedAt = startedAt;
    answeredInRound = roundId;
  }
}
