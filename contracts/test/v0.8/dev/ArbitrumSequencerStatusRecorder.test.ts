import { ethers, network } from 'hardhat'
import { Contract, BigNumber } from 'ethers'
import { expect } from 'chai'
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers'

const now = () => BigNumber.from(Date.now()).div(1000)

describe('ArbitrumSequencerStatusRecorder', () => {
  let flags: Contract
  let arbitrumSequencerStatusRecorder: Contract
  let accessController: Contract
  let arbitrumSequencerStatusRecorderConsumer: Contract
  let deployer: SignerWithAddress
  let l1Owner: SignerWithAddress
  let l2Messenger: SignerWithAddress
  before(async () => {
    const accounts = await ethers.getSigners()
    deployer = accounts[0]
    l1Owner = accounts[1]
    const dummy = accounts[2]
    const l2MessengerAddress = ethers.utils.getAddress(
      BigNumber.from(l1Owner.address)
        .add('0x1111000000000000000000000000000000001111')
        .toHexString(),
    )
    // Pretend we're on L2
    await network.provider.request({
      method: 'hardhat_impersonateAccount',
      params: [l2MessengerAddress],
    })
    l2Messenger = await ethers.getSigner(l2MessengerAddress)
    // Credit the L2 messenger with some ETH
    await dummy.sendTransaction({
      to: l2Messenger.address,
      value: (await dummy.getBalance()).sub(ethers.utils.parseEther('0.1')),
    })
  })

  beforeEach(async () => {
    const accessControllerFactory = await ethers.getContractFactory(
      'src/v0.8/SimpleWriteAccessController.sol:SimpleWriteAccessController',
      deployer,
    )
    accessController = await accessControllerFactory.deploy()

    const flagsHistoryFactory = await ethers.getContractFactory(
      'src/v0.8/dev/Flags.sol:Flags',
      deployer,
    )
    flags = await flagsHistoryFactory.deploy(
      accessController.address,
      accessController.address,
    )
    await accessController.addAccess(flags.address)

    const arbitrumSequencerStatusRecorderFactory =
      await ethers.getContractFactory(
        'src/v0.8/dev/ArbitrumSequencerStatusRecorder.sol:ArbitrumSequencerStatusRecorder',
        deployer,
      )
    arbitrumSequencerStatusRecorder =
      await arbitrumSequencerStatusRecorderFactory.deploy(
        flags.address,
        l1Owner.address,
      )
    // Required for ArbitrumSequencerStatusRecorder to raise/lower flags
    await accessController.addAccess(arbitrumSequencerStatusRecorder.address)
    // Required for ArbitrumSequencerStatusRecorder to read flags
    await flags.addAccess(arbitrumSequencerStatusRecorder.address)

    // Deployer requires access to invoke initialize
    await accessController.addAccess(deployer.address)
    // Once ArbitrumSequencerStatusRecorder has access, we can initialise the 0th aggregator round
    const initTx = await arbitrumSequencerStatusRecorder
      .connect(deployer)
      .initialize()
    await expect(initTx).to.emit(arbitrumSequencerStatusRecorder, 'Initialized')

    // Mock consumer
    const arbitrumSequencerStatusRecorderConsumerFactory =
      await ethers.getContractFactory(
        'src/v0.8/tests/ArbitrumSequencerStatusRecorderConsumer.sol:ArbitrumSequencerStatusRecorderConsumer',
        deployer,
      )
    arbitrumSequencerStatusRecorderConsumer =
      await arbitrumSequencerStatusRecorderConsumerFactory.deploy(
        arbitrumSequencerStatusRecorder.address,
      )
  })

  describe('#updateStatus', () => {
    it('should only update status when status has changed', async () => {
      let timestamp = now()
      let tx = await arbitrumSequencerStatusRecorder
        .connect(l2Messenger)
        .updateStatus(true, timestamp)
      await expect(tx)
        .to.emit(arbitrumSequencerStatusRecorder, 'AnswerUpdated')
        .withArgs(1, 1 /** roundId */, timestamp)
      expect(await arbitrumSequencerStatusRecorder.latestAnswer()).to.equal(1)

      // Submit another status update, same status, should ignore
      timestamp = now()
      tx = await arbitrumSequencerStatusRecorder
        .connect(l2Messenger)
        .updateStatus(true, timestamp)
      await expect(tx).not.to.emit(
        arbitrumSequencerStatusRecorder,
        'AnswerUpdated',
      )
      expect(await arbitrumSequencerStatusRecorder.latestAnswer()).to.equal('1')
      expect(await arbitrumSequencerStatusRecorder.latestTimestamp()).to.equal(
        timestamp,
      )

      // Submit another status update, different status, should update
      timestamp = now()
      tx = await arbitrumSequencerStatusRecorder
        .connect(l2Messenger)
        .updateStatus(false, timestamp)
      await expect(tx)
        .to.emit(arbitrumSequencerStatusRecorder, 'AnswerUpdated')
        .withArgs(0, 2 /** roundId */, timestamp)
      expect(await arbitrumSequencerStatusRecorder.latestAnswer()).to.equal(0)
      expect(await arbitrumSequencerStatusRecorder.latestTimestamp()).to.equal(
        timestamp,
      )
    })

    it('should consume a known amount of gas', async () => {
      // Sanity - start at flag = 0 (`false`)
      expect(await arbitrumSequencerStatusRecorder.latestAnswer()).to.equal(0)

      // Gas for no update
      const _noUpdateTx = await arbitrumSequencerStatusRecorder
        .connect(l2Messenger)
        .updateStatus(false, now())
      const noUpdateTx = await _noUpdateTx.wait(1)
      // Assert no update
      expect(await arbitrumSequencerStatusRecorder.latestAnswer()).to.equal(0)
      expect(noUpdateTx.cumulativeGasUsed).to.equal(26436)

      // Gas for update
      const _updateTx = await arbitrumSequencerStatusRecorder
        .connect(l2Messenger)
        .updateStatus(true, now())
      const updateTx = await _updateTx.wait(1)
      // Assert update
      expect(await arbitrumSequencerStatusRecorder.latestAnswer()).to.equal(1)
      expect(updateTx.cumulativeGasUsed).to.equal(92939)
    })
  })

  describe('AggregatorV3Interface', () => {
    it('should return valid answer from getRoundData and latestRoundData', async () => {
      let [roundId, answer, startedAt, updatedAt, answeredInRound] =
        await arbitrumSequencerStatusRecorder.getRoundData(0)
      expect(roundId).to.equal(0)
      expect(answer).to.equal(0)
      expect(answeredInRound).to.equal(roundId)
      expect(startedAt).to.equal(updatedAt)

      // Submit status update with different status, should update
      const timestamp = now()
      await arbitrumSequencerStatusRecorder
        .connect(l2Messenger)
        .updateStatus(true, timestamp)
      ;[roundId, answer, startedAt, updatedAt, answeredInRound] =
        await arbitrumSequencerStatusRecorder.getRoundData(1)
      expect(roundId).to.equal(1)
      expect(answer).to.equal(1)
      expect(answeredInRound).to.equal(roundId)
      expect(startedAt).to.equal(timestamp)
      expect(updatedAt).to.equal(startedAt)

      // Assert latestRoundData corresponds to latest round id
      expect(
        await arbitrumSequencerStatusRecorder.getRoundData(1),
      ).to.deep.equal(await arbitrumSequencerStatusRecorder.latestRoundData())
    })

    it('should raise from #getRoundData when round does not exist', async () => {
      await expect(
        arbitrumSequencerStatusRecorder.getRoundData(1),
      ).to.be.revertedWith('No data present')
    })
  })

  describe('Protect reads on AggregatorV2V3Interface functions', () => {
    it('should disallow reads on AggregatorV2V3Interface functions when consuming contract is not whitelisted', async () => {
      // Sanity - consumer is not whitelisted
      expect(await arbitrumSequencerStatusRecorder.checkEnabled()).to.be.true
      expect(
        await arbitrumSequencerStatusRecorder.hasAccess(
          arbitrumSequencerStatusRecorderConsumer.address,
          '0x00',
        ),
      ).to.be.false

      // Assert reads are not possible from consuming contract
      await expect(
        arbitrumSequencerStatusRecorderConsumer.getAggregatorV2Answer(),
      ).to.be.revertedWith('No access')
      await expect(
        arbitrumSequencerStatusRecorderConsumer.getAggregatorV3Answer(),
      ).to.be.revertedWith('No access')
    })

    it('should allow reads on AggregatorV2V3Interface functions when consuming contract is whitelisted', async () => {
      // Whitelist consumer
      await arbitrumSequencerStatusRecorder.addAccess(
        arbitrumSequencerStatusRecorderConsumer.address,
      )
      // Sanity - consumer is whitelisted
      expect(await arbitrumSequencerStatusRecorder.checkEnabled()).to.be.true
      expect(
        await arbitrumSequencerStatusRecorder.hasAccess(
          arbitrumSequencerStatusRecorderConsumer.address,
          '0x00',
        ),
      ).to.be.true

      // Assert reads are possible from consuming contract
      expect(
        await arbitrumSequencerStatusRecorderConsumer.getAggregatorV2Answer(),
      ).to.be.equal('0')
      const [roundId, answer] =
        await arbitrumSequencerStatusRecorderConsumer.getAggregatorV3Answer()
      expect(roundId).to.equal(0)
      expect(answer).to.equal(0)
    })
  })
})
