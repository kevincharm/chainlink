// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {L2SequencerUptimeFeed} from "./L2SequencerUptimeFeed.sol";
import {ArbitrumCrossDomainContext} from "./ArbitrumCrossDomainContext.sol";
import {CrossDomainContextInterface} from "./interfaces/CrossDomainContextInterface.sol";
import {TypeAndVersionInterface} from "../interfaces/TypeAndVersionInterface.sol";

/**
 * @title ArbitrumSequencerUptimeFeed - Arbitrum sequencer uptime status aggregator
 * @notice L2 contract that receives status updates from a specific L1 address,
 *  records a new answer if the status changed, and raises or lowers the flag on the
 *   stored Flags contract.
 */
contract ArbitrumSequencerUptimeFeed is ArbitrumCrossDomainContext, L2SequencerUptimeFeed {
  constructor(address flagsAddress, address l1SenderAddress)
    ArbitrumCrossDomainContext()
    L2SequencerUptimeFeed(flagsAddress, l1SenderAddress)
  {
    // noop
  }

  /**
   * @notice versions:
   *
   * - ArbitrumSequencerUptimeFeed 1.0.0: initial release
   *
   * @inheritdoc TypeAndVersionInterface
   */
  function typeAndVersion()
    external
    pure
    virtual
    override(L2SequencerUptimeFeed, ArbitrumCrossDomainContext)
    returns (string memory)
  {
    return "ArbitrumSequencerUptimeFeed 1.0.0";
  }

  /// @notice Get the L1 address of msg.sender
  function getCrossDomainMsgSender()
    public
    view
    virtual
    override(L2SequencerUptimeFeed, ArbitrumCrossDomainContext)
    returns (address)
  {
    return super.getCrossDomainMsgSender();
  }
}
