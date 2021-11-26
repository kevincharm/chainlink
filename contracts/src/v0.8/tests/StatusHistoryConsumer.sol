// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {StatusHistory} from "../dev/StatusHistory.sol";

contract StatusHistoryConsumer {
  StatusHistory public immutable STATUS_HISTORY;

  constructor(address statusHistoryAddress) {
    STATUS_HISTORY = StatusHistory(statusHistoryAddress);
  }

  function getAggregatorV2Answer() external view returns (int256 answer) {
    return STATUS_HISTORY.latestAnswer();
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
    return STATUS_HISTORY.latestRoundData();
  }
}
