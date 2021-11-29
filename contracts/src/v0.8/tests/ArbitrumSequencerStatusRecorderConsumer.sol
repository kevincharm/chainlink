// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ArbitrumSequencerStatusRecorder} from "../dev/ArbitrumSequencerStatusRecorder.sol";

contract ArbitrumSequencerStatusRecorderConsumer {
  ArbitrumSequencerStatusRecorder public immutable SEQ_STATUS_RECORDER;

  constructor(address arbitrumSequencerStatusRecorderAddress) {
    SEQ_STATUS_RECORDER = ArbitrumSequencerStatusRecorder(arbitrumSequencerStatusRecorderAddress);
  }

  function getAggregatorV2Answer() external view returns (int256 answer) {
    return SEQ_STATUS_RECORDER.latestAnswer();
  }

  function getAggregatorV3Answer()
    external
    view
    returns (
      uint80 roundId,
      int256 answer,
      uint256 startedAt,
      uint256 updatedAt,
      uint80 answeredInRound
    )
  {
    return SEQ_STATUS_RECORDER.latestRoundData();
  }
}
