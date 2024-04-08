import { expect } from "chai";
import { ethers } from "hardhat";
import { LUBE, LUBE__factory } from "../typechain";
import { BigNumber, Wallet } from "ethers";

describe("LUBE Token Tests", function () {
  let lube: LUBE;
  let owner: Wallet, taxAddress: Wallet, userAddress1: Wallet, userAddress2: Wallet, poolAddress: Wallet;

  beforeEach(async function () {
    // Define a set of addresses for use in the tests
    // owner - contract deployer
    // taxAddress - destination of taxes
    // userAddress1 - a user of the product
    // userAddress2 - a second user of the product
    // poolAddress - the pool or vault address from which taxes are collected
    [owner, taxAddress, userAddress1, userAddress2, poolAddress] = await ethers.getSigners();

    // Deploy the contracts
    const lubeFactory = (await ethers.getContractFactory("LUBE", owner)) as LUBE__factory;
    lube = await lubeFactory.deploy("LUBE Token", "LUBE", taxAddress.address);
    await lube.deployed();

    // Setup the pool address
    await lube.setPoolAddress(poolAddress.address);
  });

  it("Should not charge tax when transferring between non-pool addresses", async function () {
    const amount = ethers.utils.parseUnits("1000", 18);

    await lube.transfer(userAddress1.address, amount);
    await lube.connect(userAddress1).transfer(userAddress2.address, amount);

    const finalBalance = await lube.balanceOf(userAddress2.address);
    expect(finalBalance).to.equal(amount);
  });

  it("Should set the pool address correctly", async function () {
    await lube.setPoolAddress(poolAddress.address);
    expect(await lube.taxedPoolAddress()).to.equal(poolAddress.address);
  });

  it("Should charge tax when transferring to the pool address", async function () {
    const amount = ethers.utils.parseUnits("1000", 18);
    const taxBasisPoints = 150; // 150 basis points
    const expectedTax = amount.mul(taxBasisPoints).div(10000);

    await lube.setPoolAddress(poolAddress.address);
    await lube.transfer(poolAddress.address, amount);

    const finalBalance = await lube.balanceOf(poolAddress.address);
    expect(finalBalance).to.equal(amount.sub(expectedTax));
  });

  it("Should charge tax when transferring from the pool address", async function () {
    const amount = ethers.utils.parseUnits("1000", 18);
    const taxBasisPoints = 150; // 150 basis points
    const expectedTax = amount.mul(taxBasisPoints).div(10000);

    await lube.setPoolAddress(poolAddress.address);

    // Transfer to the tax address first, to avoid paying fees when transferring to the pool
    await lube.transfer(taxAddress.address, amount);

    // Transfer into the pool address
    await lube.connect(taxAddress).transfer(poolAddress.address, amount);

    // Then transfer from the pool address to another address
    await lube.connect(poolAddress).transfer(userAddress1.address, amount);

    const finalBalance = await lube.balanceOf(userAddress1.address);
    expect(finalBalance).to.equal(amount.sub(expectedTax));
  });

  it("Should not allow non-owners to set the pool/exempt address", async function () {
    // Attempt to set the pool address from a non-owner account
    await expect(lube.connect(userAddress1).setPoolAddress(poolAddress.address)).to.be.revertedWith(
      "Ownable: caller is not the owner",
    );
  });

  it("Should set approvals correctly", async function () {
    const approvalAmount = ethers.utils.parseUnits("1000", 18);
    await lube.approve(userAddress1.address, approvalAmount);

    expect(await lube.allowance(owner.address, userAddress1.address)).to.equal(approvalAmount);
  });

  it("Should emit an Approval event when approval is granted", async function () {
    const approvalAmount = ethers.utils.parseUnits("1000", 18);
    await expect(lube.approve(userAddress1.address, approvalAmount))
      .to.emit(lube, "Approval")
      .withArgs(owner.address, userAddress1.address, approvalAmount);
  });

  it("Should overwrite previous approvals", async function () {
    const initialAmount = ethers.utils.parseUnits("1000", 18);
    const newAmount = ethers.utils.parseUnits("500", 18);

    await lube.approve(userAddress1.address, initialAmount);
    await lube.approve(userAddress1.address, newAmount);

    expect(await lube.allowance(owner.address, userAddress1.address)).to.equal(newAmount);
  });

  it("Should only allow transferFrom within the approved amount", async function () {
    const approvalAmount: BigNumber = ethers.utils.parseUnits("1000", 18);
    const transferAmount: BigNumber = ethers.utils.parseUnits("500", 18);
    const excessAmount: BigNumber = ethers.utils.parseUnits("1500", 18);

    // Owner approves addr1 to spend a specific amount
    await lube.approve(userAddress1.address, approvalAmount);

    // Attempt to exceed the approved amount
    await expect(
      lube.connect(userAddress1).transferFrom(owner.address, userAddress2.address, excessAmount),
    ).to.be.revertedWith("LUBE:transferFrom:ALLOWANCE_EXCEEDED");

    // Successfully transfer an amount within the limit
    await expect(lube.connect(userAddress1).transferFrom(owner.address, userAddress2.address, transferAmount))
      .to.emit(lube, "Transfer")
      .withArgs(owner.address, userAddress2.address, transferAmount);

    // Check final balance of addr2 to confirm the transfer
    expect(await lube.balanceOf(userAddress2.address)).to.equal(transferAmount);

    // Check the remaining allowance
    const remainingAllowance = await lube.allowance(owner.address, userAddress1.address);
    expect(remainingAllowance).to.equal(approvalAmount.sub(transferAmount));
  });

  it("Cannot transfer greater than balance", async function () {
    const ownerBalance: BigNumber = await lube.balanceOf(owner.address);
    const excessiveAmount: BigNumber = ownerBalance.add(1); // Amount greater than owner's balance

    // Attempt to transfer more than the owner's balance
    await expect(lube.transfer(userAddress1.address, excessiveAmount)).to.be.revertedWith(
      "LUBE:_transfer:INSUFFICIENT_BALANCE",
    );
  });

  it("Cannot transfer greater than balance", async function () {
    const ownerBalance: BigNumber = await lube.balanceOf(owner.address);
    const excessiveAmount: BigNumber = ownerBalance.add(1); // Amount greater than owner's balance

    // Attempt to transfer more than the owner's balance
    await expect(lube.transfer(userAddress1.address, excessiveAmount)).to.be.revertedWith(
      "LUBE:_transfer:INSUFFICIENT_BALANCE",
    );
  });

  it("Should prevent integer overflow in transfer", async function () {
    // n.b. This is prevented courtesy of us compiling with solidity > 0.8.x,
    // however it's always good to wear a tinfoil hat when it comes to this stuff.

    const initialBalance = await lube.balanceOf(userAddress1.address);
    const excessiveAmount = ethers.constants.MaxUint256.sub(initialBalance).add(1);

    // Owner tries to transfer a very large amount that would cause recipient's balance to overflow
    await expect(lube.transfer(userAddress1.address, excessiveAmount)).to.be.reverted;
  });

  it("Should only allow the owner to transfer ownership", async function () {
    // Attempt to transfer ownership from a non-owner account
    await expect(lube.connect(userAddress1).transferOwnership(userAddress2.address)).to.be.revertedWith(
      "Ownable: caller is not the owner",
    );
  });

  it("Should transfer ownership correctly", async function () {
    await lube.transferOwnership(userAddress1.address);

    expect(await lube.owner()).to.equal(userAddress1.address);
  });

  it("Should only allow the owner to renounce ownership", async function () {
    // Attempt to renounce ownership from a non-owner account
    await expect(lube.connect(userAddress1).renounceOwnership()).to.be.revertedWith("Ownable: caller is not the owner");
  });

  it("Should renounce ownership correctly", async function () {
    await lube.renounceOwnership();

    // After renouncing, the owner is the zero address
    expect(await lube.owner()).to.equal(ethers.constants.AddressZero);

    // The original owner can't change properties after transferring
    await expect(lube.setPoolAddress(poolAddress.address)).to.be.revertedWith("Ownable: caller is not the owner");
    await expect(lube.setTaxExemptAddress(poolAddress.address)).to.be.revertedWith("Ownable: caller is not the owner");
  });
});
