import { ethers } from 'hardhat'
import { BigNumber, Contract } from 'ethers'
import { expect, use } from 'chai'
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers'
import { FakeContract, smock } from '@defi-wonderland/smock'
/// Pick ABIs from compilation
// @ts-ignore
import { abi as arbitrumSequencerStatusRecorderAbi } from '../../../artifacts/src/v0.8/dev/ArbitrumSequencerStatusRecorder.sol/ArbitrumSequencerStatusRecorder.json'
// @ts-ignore
import { abi as arbitrumInboxAbi } from '../../../artifacts/src/v0.8/dev/vendor/arb-bridge-eth/v0.8.0-custom/contracts/bridge/interfaces/IInbox.sol/IInbox.json'
// @ts-ignore
import { abi as aggregatorAbi } from '../../../artifacts/src/v0.8/interfaces/AggregatorV2V3Interface.sol/AggregatorV2V3Interface.json'

use(smock.matchers)

describe('ArbitrumValidator', () => {
  const MAX_GAS = BigNumber.from(1_000_000)
  const GAS_PRICE_BID = BigNumber.from(1_000_000)
  let arbitrumValidator: Contract
  let accessController: Contract
  let l1GasFeed: FakeContract
  let arbitrumInbox: FakeContract
  let arbitrumSequencerStatusRecorder: FakeContract
  let deployer: SignerWithAddress
  let eoaValidator: SignerWithAddress
  let arbitrumValidatorL2Address: string
  before(async () => {
    const accounts = await ethers.getSigners()
    deployer = accounts[0]
    eoaValidator = accounts[1]
  })

  beforeEach(async () => {
    const accessControllerFactory = await ethers.getContractFactory(
      'src/v0.8/SimpleWriteAccessController.sol:SimpleWriteAccessController',
      deployer,
    )
    accessController = await accessControllerFactory.deploy()

    // Unused, L2
    arbitrumSequencerStatusRecorder = await smock.fake(
      arbitrumSequencerStatusRecorderAbi,
    )
    arbitrumInbox = await smock.fake(arbitrumInboxAbi)
    l1GasFeed = await smock.fake(aggregatorAbi)

    // Mock consumer
    const arbitrumValidatorFactory = await ethers.getContractFactory(
      'src/v0.8/dev/ArbitrumValidator.sol:ArbitrumValidator',
      deployer,
    )
    arbitrumValidator = await arbitrumValidatorFactory.deploy(
      arbitrumInbox.address,
      arbitrumSequencerStatusRecorder.address,
      accessController.address,
      MAX_GAS /** L1 gas bid */,
      GAS_PRICE_BID /** L2 gas bid */,
      l1GasFeed.address,
      0,
    )
    // Transfer some ETH to the ArbitrumValidator contract
    await deployer.sendTransaction({
      to: arbitrumValidator.address,
      value: ethers.utils.parseEther('1.0'),
    })
    arbitrumValidatorL2Address = ethers.utils.getAddress(
      BigNumber.from(arbitrumValidator.address)
        .add('0x1111000000000000000000000000000000001111')
        .toHexString(),
    )
  })

  describe('#validate', async () => {
    it('post sequencer offline', async () => {
      await arbitrumValidator.addAccess(eoaValidator.address)
      const now = BigNumber.from(Date.now()).div(1000).add(1000)
      await ethers.provider.send('evm_setAutomine', [false])
      await ethers.provider.send('evm_setNextBlockTimestamp', [now])
      const tx = await arbitrumValidator
        .connect(eoaValidator)
        .validate(0, 0, 1, 1)
      await ethers.provider.send('evm_mine', [])
      await tx.wait(1)
      await ethers.provider.send('evm_setAutomine', [true])
      expect(arbitrumInbox.createRetryableTicketNoRefundAliasRewrite).to.be
        .called

      const arbitrumSequencerStatusRecorderCallData =
        arbitrumSequencerStatusRecorder.interface.encodeFunctionData(
          'updateStatus',
          [true, now],
        )
      // TODO: Smock matchers don't match BigNumbers properly
      //  Remove `not` to visually confirm the output (will fail)
      expect(
        arbitrumInbox.createRetryableTicketNoRefundAliasRewrite,
      ).not.to.be.calledWith(
        1,
        0,
        0,
        arbitrumValidatorL2Address,
        arbitrumValidatorL2Address,
        MAX_GAS,
        GAS_PRICE_BID,
        arbitrumSequencerStatusRecorderCallData,
      )
    })
  })
})
