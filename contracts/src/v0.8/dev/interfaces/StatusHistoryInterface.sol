// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface StatusHistoryInterface {
  function statusUpdated(bool status, uint64 timestamp) external;
}
