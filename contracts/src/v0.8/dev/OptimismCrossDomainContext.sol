// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {AddressAliasHelper} from "./vendor/arb-bridge-eth/v0.8.0-custom/contracts/libraries/AddressAliasHelper.sol";
import {CrossDomainContextInterface} from "./interfaces/CrossDomainContextInterface.sol";
import {TypeAndVersionInterface} from "../interfaces/TypeAndVersionInterface.sol";
import {iOVM_CrossDomainMessenger} from "./vendor/@eth-optimism/contracts/0.4.7/contracts/optimistic-ethereum/iOVM/bridge/messaging/iOVM_CrossDomainMessenger.sol";

/**
 * @title OptimismCrossDomainContext - L2 contract that receives messages from L1
 * @notice L2 contract that receives messages from an L1 address, and provides a helper
 *    for calculating the sender of incoming messages.
 */
abstract contract OptimismCrossDomainContext is TypeAndVersionInterface {
  // OVM_L2CrossDomainMessenger is a precompile usually deployed to 0x4200000000000000000000000000000000000007
  iOVM_CrossDomainMessenger private immutable OVM_CROSS_DOMAIN_MESSENGER;

  /**
   * @notice creates a new Optimism xDomain Forwarder contract
   * @param crossDomainMessengerAddr the xDomain bridge messenger (Optimism bridge L2) contract address
   */
  constructor(address crossDomainMessengerAddr) {
    require(crossDomainMessengerAddr != address(0), "Invalid xDomain Messenger address");
    OVM_CROSS_DOMAIN_MESSENGER = iOVM_CrossDomainMessenger(crossDomainMessengerAddr);
  }

  /**
   * @notice versions:
   *
   * - OptimismCrossDomainContext 1.0.0: initial release
   *
   * @inheritdoc TypeAndVersionInterface
   */
  function typeAndVersion() external pure virtual override returns (string memory) {
    return "OptimismCrossDomainContext 1.0.0";
  }

  /// @notice Get the L1 address of msg.sender
  function getCrossDomainMsgSender() public view virtual returns (address) {
    require(msg.sender == address(OVM_CROSS_DOMAIN_MESSENGER), "Sender is not OVM xDomain Messenger");
    return OVM_CROSS_DOMAIN_MESSENGER.xDomainMessageSender();
  }
}
