// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {AddressAliasHelper} from "./vendor/arb-bridge-eth/v0.8.0-custom/contracts/libraries/AddressAliasHelper.sol";
import {TypeAndVersionInterface} from "../interfaces/TypeAndVersionInterface.sol";

/**
 * @title ArbitrumCrossDomainContext - L2 contract that receives messages from L1
 * @notice L2 contract that receives messages from an L1 address, and provides a helper
 *    for calculating the sender of incoming messages.
 */
abstract contract ArbitrumCrossDomainContext is TypeAndVersionInterface {
  constructor() {
    // noop
  }

  /**
   * @notice versions:
   *
   * - ArbitrumCrossDomainContext 1.0.0: initial release
   *
   * @inheritdoc TypeAndVersionInterface
   */
  function typeAndVersion() external pure virtual override returns (string memory) {
    return "ArbitrumCrossDomainContext 1.0.0";
  }

  /// @notice Get the L1 address of msg.sender
  function getCrossDomainMsgSender() public view virtual returns (address) {
    return AddressAliasHelper.undoL1ToL2Alias(msg.sender);
  }
}
