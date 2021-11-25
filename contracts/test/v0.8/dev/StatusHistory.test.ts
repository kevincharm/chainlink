import { ethers, network } from 'hardhat'
import { Contract, BigNumber } from 'ethers'
import { expect } from 'chai'
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers'

const now = () => BigNumber.from(Date.now()).div(1000)

describe('StatusHistory', () => {
  let flags: Contract
  let statusHistory: Contract
  let accessController: Contract
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

    const statusHistoryFactory = await ethers.getContractFactory(
      'src/v0.8/dev/StatusHistory.sol:StatusHistory',
      deployer,
    )
    statusHistory = await statusHistoryFactory.deploy(
      flags.address,
      l1Owner.address,
    )
    // Required for StatusHistory to raise/lower flags
    await accessController.addAccess(statusHistory.address)
    // Required for StatusHistory to read flags
    await flags.addAccess(statusHistory.address)

    // Deployer requires access to invoke initialize
    await accessController.addAccess(deployer.address)
    // Once StatusHistory has access, we can initialise the 0th aggregator round
    const initTx = await statusHistory.connect(deployer).initialize()
    await expect(initTx).to.emit(statusHistory, 'Initialized')
  })

  describe('#statusUpdated', () => {
    it('should only update status when status has changed', async () => {
      let timestamp = now()
      let tx = await statusHistory
        .connect(l2Messenger)
        .statusUpdated(true, timestamp)
      await expect(tx)
        .to.emit(statusHistory, 'AnswerUpdated')
        .withArgs(1, 1 /** roundId */, timestamp)
      expect(await statusHistory.latestAnswer()).to.equal(1)

      // Submit another status update, same status, should ignore
      timestamp = now()
      tx = await statusHistory
        .connect(l2Messenger)
        .statusUpdated(true, timestamp)
      await expect(tx).not.to.emit(statusHistory, 'AnswerUpdated')
      expect(await statusHistory.latestAnswer()).to.equal('1')

      // Submit another status update, different status, should update
      timestamp = now()
      tx = await statusHistory
        .connect(l2Messenger)
        .statusUpdated(false, timestamp)
      await expect(tx)
        .to.emit(statusHistory, 'AnswerUpdated')
        .withArgs(0, 2 /** roundId */, timestamp)
      expect(await statusHistory.latestAnswer()).to.equal(0)
    })
  })

  describe('AggregatorV3Interface', () => {
    it('should return valid answer from getRoundData and latestRoundData', async () => {
      let [roundId, answer, startedAt, updatedAt, answeredInRound] =
        await statusHistory.getRoundData(0)
      expect(roundId).to.equal(0)
      expect(answer).to.equal(0)
      expect(answeredInRound).to.equal(roundId)
      expect(startedAt).to.equal(updatedAt)

      // Submit status update with different status, should update
      const timestamp = now()
      await statusHistory.connect(l2Messenger).statusUpdated(true, timestamp)
      ;[roundId, answer, startedAt, updatedAt, answeredInRound] =
        await statusHistory.getRoundData(1)
      expect(roundId).to.equal(1)
      expect(answer).to.equal(1)
      expect(answeredInRound).to.equal(roundId)
      expect(startedAt).to.equal(timestamp)
      expect(updatedAt).to.equal(startedAt)

      // Assert latestRoundData corresponds to latest round id
      expect(await statusHistory.getRoundData(1)).to.deep.equal(
        await statusHistory.latestRoundData(),
      )
    })

    it('should raise from getRoundData when round does not exist', async () => {
      await expect(statusHistory.getRoundData(1)).to.be.revertedWith(
        'No data present',
      )
    })
  })
})
