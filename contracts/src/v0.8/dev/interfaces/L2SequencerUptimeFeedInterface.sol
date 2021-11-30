// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface L2SequencerUptimeFeedInterface {
  function updateStatus(bool status, uint64 timestamp) external;
}
