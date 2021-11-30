// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title CrossDomainContextInterface - L2 contract that receives messages from L1
interface CrossDomainContextInterface {
  /// @notice Get the L1 address of msg.sender
  function getCrossDomainMsgSender() external view returns (address);
}
