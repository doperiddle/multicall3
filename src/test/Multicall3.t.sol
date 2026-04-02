// SPDX-License-Identifier: MIT
pragma solidity 0.8.12;

import {Test} from "forge-std/Test.sol";
import {Multicall3} from "../Multicall3.sol";
import {MockCallee} from "./mocks/MockCallee.sol";
import {EtherSink} from "./mocks/EtherSink.sol";

contract Multicall3Test is Test {
  Multicall3 multicall;
  MockCallee callee;
  EtherSink etherSink;

  /// @notice Designated receiving and fee recipient address
  address constant RECIPIENT = 0xf333907BaF09DC58ad4Ba39Af94009801C825531;

  /// @notice Setups up the testing suite
  function setUp() public {
    multicall = new Multicall3();
    callee = new MockCallee();
    etherSink = new EtherSink();
  }

  /// >>>>>>>>>>>>>>>>>>>>>  AGGREGATE TESTS  <<<<<<<<<<<<<<<<<<<<< ///

  function testAggregation() public {
    // Test successful call
    Multicall3.Call[] memory calls = new Multicall3.Call[](1);
    calls[0] = Multicall3.Call(address(callee), abi.encodeWithSignature("getBlockHash(uint256)", block.number));
    (uint256 blockNumber, bytes[] memory returnData) = multicall.aggregate(calls);
    assertEq(blockNumber, block.number);
    assertEq(keccak256(returnData[0]), keccak256(abi.encodePacked(blockhash(block.number))));
  }

  function testUnsuccessfulAggregation() public {
    // Test unexpected revert
    Multicall3.Call[] memory calls = new Multicall3.Call[](2);
    calls[0] = Multicall3.Call(address(callee), abi.encodeWithSignature("getBlockHash(uint256)", block.number));
    calls[1] = Multicall3.Call(address(callee), abi.encodeWithSignature("thisMethodReverts()"));
    vm.expectRevert(bytes("Multicall3: call failed"));
    multicall.aggregate(calls);
  }

  /// >>>>>>>>>>>>>>>>>>>  TRY AGGREGATE TESTS  <<<<<<<<<<<<<<<<<<< ///

  function testTryAggregate() public {
    Multicall3.Call[] memory calls = new Multicall3.Call[](2);
    calls[0] = Multicall3.Call(address(callee), abi.encodeWithSignature("getBlockHash(uint256)", block.number));
    calls[1] = Multicall3.Call(address(callee), abi.encodeWithSignature("thisMethodReverts()"));
    (Multicall3.Result[] memory returnData) = multicall.tryAggregate(false, calls);
    assertTrue(returnData[0].success);
    assertEq(keccak256(returnData[0].returnData), keccak256(abi.encodePacked(blockhash(block.number))));
    assertTrue(!returnData[1].success);
  }

  function testTryAggregateUnsuccessful() public {
    Multicall3.Call[] memory calls = new Multicall3.Call[](2);
    calls[0] = Multicall3.Call(address(callee), abi.encodeWithSignature("getBlockHash(uint256)", block.number));
    calls[1] = Multicall3.Call(address(callee), abi.encodeWithSignature("thisMethodReverts()"));
    vm.expectRevert(bytes("Multicall3: call failed"));
    multicall.tryAggregate(true, calls);
  }

  /// >>>>>>>>>>>>>>  TRY BLOCK AND AGGREGATE TESTS  <<<<<<<<<<<<<< ///

  function testTryBlockAndAggregate() public {
    Multicall3.Call[] memory calls = new Multicall3.Call[](2);
    calls[0] = Multicall3.Call(address(callee), abi.encodeWithSignature("getBlockHash(uint256)", block.number));
    calls[1] = Multicall3.Call(address(callee), abi.encodeWithSignature("thisMethodReverts()"));
    (uint256 blockNumber, bytes32 blockHash, Multicall3.Result[] memory returnData) = multicall.tryBlockAndAggregate(false, calls);
    assertEq(blockNumber, block.number);
    assertEq(blockHash, blockhash(block.number));
    assertTrue(returnData[0].success);
    assertEq(keccak256(returnData[0].returnData), keccak256(abi.encodePacked(blockhash(block.number))));
    assertTrue(!returnData[1].success);
  }

  function testTryBlockAndAggregateUnsuccessful() public {
    Multicall3.Call[] memory calls = new Multicall3.Call[](2);
    calls[0] = Multicall3.Call(address(callee), abi.encodeWithSignature("getBlockHash(uint256)", block.number));
    calls[1] = Multicall3.Call(address(callee), abi.encodeWithSignature("thisMethodReverts()"));
    vm.expectRevert(bytes("Multicall3: call failed"));
    multicall.tryBlockAndAggregate(true, calls);
  }

  function testBlockAndAggregateUnsuccessful() public {
    Multicall3.Call[] memory calls = new Multicall3.Call[](2);
    calls[0] = Multicall3.Call(address(callee), abi.encodeWithSignature("getBlockHash(uint256)", block.number));
    calls[1] = Multicall3.Call(address(callee), abi.encodeWithSignature("thisMethodReverts()"));
    vm.expectRevert(bytes("Multicall3: call failed"));
    multicall.blockAndAggregate(calls);
  }

  /// >>>>>>>>>>>>>>>>>>>  AGGREGATE3 TESTS  <<<<<<<<<<<<<<<<<<<<<< ///

  function testAggregate3() public {
    Multicall3.Call3[] memory calls = new Multicall3.Call3[](3);
    calls[0] = Multicall3.Call3(address(callee), false, abi.encodeWithSignature("getBlockHash(uint256)", block.number));
    calls[1] = Multicall3.Call3(address(callee), true, abi.encodeWithSignature("thisMethodReverts()"));
    calls[2] = Multicall3.Call3(address(multicall), true, abi.encodeWithSignature("getCurrentBlockTimestamp()"));
    (Multicall3.Result[] memory returnData) = multicall.aggregate3(calls);

    // Call 1.
    assertTrue(returnData[0].success);
    assertEq(blockhash(block.number), abi.decode(returnData[0].returnData, (bytes32)));
    assertEq(keccak256(returnData[0].returnData), keccak256(abi.encodePacked(blockhash(block.number))));

    // Call 2.
    assertTrue(!returnData[1].success);
    assertEq(returnData[1].returnData.length, 4);
    assertEq(bytes4(returnData[1].returnData), bytes4(keccak256("Unsuccessful()")));

    // Call 3.
    assertTrue(returnData[2].success);
    assertEq(abi.decode(returnData[2].returnData, (uint256)), block.timestamp);
  }

  function testAggregate3Unsuccessful() public {
    Multicall3.Call3[] memory calls = new Multicall3.Call3[](2);
    calls[0] = Multicall3.Call3(address(callee), false, abi.encodeWithSignature("getBlockHash(uint256)", block.number));
    calls[1] = Multicall3.Call3(address(callee), false, abi.encodeWithSignature("thisMethodReverts()"));
    vm.expectRevert(bytes("Multicall3: call failed"));
    multicall.aggregate3(calls);
  }

  /// >>>>>>>>>>>>>>>>>  AGGREGATE3VALUE TESTS  <<<<<<<<<<<<<<<<<<< ///

  function testAggregate3Value() public {
    Multicall3.Call3Value[] memory calls = new Multicall3.Call3Value[](3);
    calls[0] = Multicall3.Call3Value(address(callee), false, 0, abi.encodeWithSignature("getBlockHash(uint256)", block.number));
    calls[1] = Multicall3.Call3Value(address(callee), true, 0, abi.encodeWithSignature("thisMethodReverts()"));
    calls[2] = Multicall3.Call3Value(address(callee), true, 1, abi.encodeWithSignature("sendBackValue(address)", address(etherSink)));
    (Multicall3.Result[] memory returnData) = multicall.aggregate3Value{value: 1}(calls);
    assertTrue(returnData[0].success);
    assertEq(keccak256(returnData[0].returnData), keccak256(abi.encodePacked(blockhash(block.number))));
    assertTrue(!returnData[1].success);
    assertTrue(returnData[2].success);
  }

  function testAggregate3ValueUnsuccessful() public {
    Multicall3.Call3Value[] memory calls = new Multicall3.Call3Value[](3);
    calls[0] = Multicall3.Call3Value(address(callee), false, 0, abi.encodeWithSignature("getBlockHash(uint256)", block.number));
    calls[1] = Multicall3.Call3Value(address(callee), false, 0, abi.encodeWithSignature("thisMethodReverts()"));
    calls[2] = Multicall3.Call3Value(address(callee), false, 1, abi.encodeWithSignature("sendBackValue(address)", address(etherSink)));
    vm.expectRevert(bytes("Multicall3: call failed"));
    multicall.aggregate3Value(calls);

    // Should fail if we don't provide enough value
    Multicall3.Call3Value[] memory calls2 = new Multicall3.Call3Value[](3);
    calls2[0] = Multicall3.Call3Value(address(callee), true, 0, abi.encodeWithSignature("getBlockHash(uint256)", block.number));
    calls2[1] = Multicall3.Call3Value(address(callee), true, 0, abi.encodeWithSignature("thisMethodReverts()"));
    calls2[2] = Multicall3.Call3Value(address(callee), true, 1, abi.encodeWithSignature("sendBackValue(address)", address(etherSink)));
    vm.expectRevert(bytes("Multicall3: value mismatch"));
    multicall.aggregate3Value(calls2);

    // Works if we provide enough value
    Multicall3.Call3Value[] memory calls3 = new Multicall3.Call3Value[](3);
    calls3[0] = Multicall3.Call3Value(address(callee), false, 0, abi.encodeWithSignature("getBlockHash(uint256)", block.number));
    calls3[1] = Multicall3.Call3Value(address(callee), true, 0, abi.encodeWithSignature("thisMethodReverts()"));
    calls3[2] = Multicall3.Call3Value(address(callee), false, 1, abi.encodeWithSignature("sendBackValue(address)", address(etherSink)));
    multicall.aggregate3Value{value: 1}(calls3);
  }

  /// >>>>>>>>>>>>>>>>>>  EMPTY CALLS ARRAY TESTS  <<<<<<<<<<<<<<<< ///

  function testAggregateEmpty() public {
    Multicall3.Call[] memory calls = new Multicall3.Call[](0);
    (uint256 blockNumber, bytes[] memory returnData) = multicall.aggregate(calls);
    assertEq(blockNumber, block.number);
    assertEq(returnData.length, 0);
  }

  function testTryAggregateEmpty() public {
    Multicall3.Call[] memory calls = new Multicall3.Call[](0);
    Multicall3.Result[] memory returnData = multicall.tryAggregate(false, calls);
    assertEq(returnData.length, 0);
  }

  function testTryAggregateEmptyRequireSuccess() public {
    Multicall3.Call[] memory calls = new Multicall3.Call[](0);
    Multicall3.Result[] memory returnData = multicall.tryAggregate(true, calls);
    assertEq(returnData.length, 0);
  }

  function testTryBlockAndAggregateEmpty() public {
    Multicall3.Call[] memory calls = new Multicall3.Call[](0);
    (uint256 blockNumber, bytes32 blockHash, Multicall3.Result[] memory returnData) = multicall.tryBlockAndAggregate(false, calls);
    assertEq(blockNumber, block.number);
    assertEq(blockHash, blockhash(block.number));
    assertEq(returnData.length, 0);
  }

  function testBlockAndAggregateEmpty() public {
    Multicall3.Call[] memory calls = new Multicall3.Call[](0);
    (uint256 blockNumber, bytes32 blockHash, Multicall3.Result[] memory returnData) = multicall.blockAndAggregate(calls);
    assertEq(blockNumber, block.number);
    assertEq(blockHash, blockhash(block.number));
    assertEq(returnData.length, 0);
  }

  function testAggregate3Empty() public {
    Multicall3.Call3[] memory calls = new Multicall3.Call3[](0);
    Multicall3.Result[] memory returnData = multicall.aggregate3(calls);
    assertEq(returnData.length, 0);
  }

  function testAggregate3ValueEmpty() public {
    Multicall3.Call3Value[] memory calls = new Multicall3.Call3Value[](0);
    Multicall3.Result[] memory returnData = multicall.aggregate3Value{value: 0}(calls);
    assertEq(returnData.length, 0);
  }

  /// >>>>>>>>>>>>>>>>  BLOCK AND AGGREGATE SUCCESS TESTS  <<<<<<<< ///

  function testBlockAndAggregateSuccess() public {
    Multicall3.Call[] memory calls = new Multicall3.Call[](2);
    calls[0] = Multicall3.Call(address(callee), abi.encodeWithSignature("getBlockHash(uint256)", block.number));
    calls[1] = Multicall3.Call(address(multicall), abi.encodeWithSignature("getBlockNumber()"));
    (uint256 blockNumber, bytes32 blockHash, Multicall3.Result[] memory returnData) = multicall.blockAndAggregate(calls);
    assertEq(blockNumber, block.number);
    assertEq(blockHash, blockhash(block.number));
    assertTrue(returnData[0].success);
    assertTrue(returnData[1].success);
    assertEq(abi.decode(returnData[1].returnData, (uint256)), block.number);
  }

  /// >>>>>>>>>>>>>  AGGREGATE3 ADDITIONAL TESTS  <<<<<<<<<<<<<<<<< ///

  function testAggregate3AllowAllFailures() public {
    Multicall3.Call3[] memory calls = new Multicall3.Call3[](2);
    calls[0] = Multicall3.Call3(address(callee), true, abi.encodeWithSignature("thisMethodReverts()"));
    calls[1] = Multicall3.Call3(address(callee), true, abi.encodeWithSignature("thisMethodReverts()"));
    Multicall3.Result[] memory returnData = multicall.aggregate3(calls);
    assertFalse(returnData[0].success);
    assertFalse(returnData[1].success);
  }

  function testAggregate3AllSucceed() public {
    Multicall3.Call3[] memory calls = new Multicall3.Call3[](2);
    calls[0] = Multicall3.Call3(address(multicall), false, abi.encodeWithSignature("getBlockNumber()"));
    calls[1] = Multicall3.Call3(address(multicall), false, abi.encodeWithSignature("getCurrentBlockTimestamp()"));
    Multicall3.Result[] memory returnData = multicall.aggregate3(calls);
    assertTrue(returnData[0].success);
    assertEq(abi.decode(returnData[0].returnData, (uint256)), block.number);
    assertTrue(returnData[1].success);
    assertEq(abi.decode(returnData[1].returnData, (uint256)), block.timestamp);
  }

  /// >>>>>>>>>>>>>  AGGREGATE3VALUE ADDITIONAL TESTS  <<<<<<<<<<<<< ///

  function testAggregate3ValueZeroSum() public {
    // All values zero — msg.value must also be zero
    Multicall3.Call3Value[] memory calls = new Multicall3.Call3Value[](2);
    calls[0] = Multicall3.Call3Value(address(multicall), false, 0, abi.encodeWithSignature("getBlockNumber()"));
    calls[1] = Multicall3.Call3Value(address(multicall), false, 0, abi.encodeWithSignature("getCurrentBlockTimestamp()"));
    Multicall3.Result[] memory returnData = multicall.aggregate3Value{value: 0}(calls);
    assertTrue(returnData[0].success);
    assertTrue(returnData[1].success);
  }

  function testAggregate3ValueExcessReverts() public {
    // Sending more ETH than the sum of call values must revert
    Multicall3.Call3Value[] memory calls = new Multicall3.Call3Value[](1);
    calls[0] = Multicall3.Call3Value(address(etherSink), false, 1, "");
    vm.deal(address(this), 2 ether);
    vm.expectRevert(bytes("Multicall3: value mismatch"));
    multicall.aggregate3Value{value: 2}(calls);
  }

  function testAggregate3ValueToRecipient() public {
    // Send ETH via aggregate3Value to the designated RECIPIENT address
    uint256 balanceBefore = RECIPIENT.balance;
    Multicall3.Call3Value[] memory calls = new Multicall3.Call3Value[](1);
    calls[0] = Multicall3.Call3Value(RECIPIENT, false, 1 ether, "");
    vm.deal(address(this), 1 ether);
    multicall.aggregate3Value{value: 1 ether}(calls);
    assertEq(RECIPIENT.balance, balanceBefore + 1 ether);
  }

  /// >>>>>>>>>>>>>>>>>  SELF-CALL TESTS  <<<<<<<<<<<<<<<<<<<<<<<<< ///

  function testAggregateSelfCall() public {
    Multicall3.Call[] memory calls = new Multicall3.Call[](2);
    calls[0] = Multicall3.Call(address(multicall), abi.encodeWithSignature("getBlockNumber()"));
    calls[1] = Multicall3.Call(address(multicall), abi.encodeWithSignature("getChainId()"));
    (uint256 blockNumber, bytes[] memory returnData) = multicall.aggregate(calls);
    assertEq(blockNumber, block.number);
    assertEq(abi.decode(returnData[0], (uint256)), block.number);
    assertEq(abi.decode(returnData[1], (uint256)), block.chainid);
  }

  function testAggregate3SelfCall() public {
    Multicall3.Call3[] memory calls = new Multicall3.Call3[](1);
    calls[0] = Multicall3.Call3(address(multicall), false, abi.encodeWithSignature("getChainId()"));
    Multicall3.Result[] memory returnData = multicall.aggregate3(calls);
    assertTrue(returnData[0].success);
    assertEq(abi.decode(returnData[0].returnData, (uint256)), block.chainid);
  }

  /// >>>>>>>>>>>>>>>>>>  ETH BALANCE TESTS  <<<<<<<<<<<<<<<<<<<<<< ///

  function testGetEthBalanceRecipient() public {
    // Fund RECIPIENT and verify getEthBalance reflects funded balance
    vm.deal(RECIPIENT, 5 ether);
    assertEq(multicall.getEthBalance(RECIPIENT), 5 ether);
  }

  function testGetEthBalanceFunded(address addr, uint96 amount) public {
    vm.deal(addr, amount);
    assertEq(multicall.getEthBalance(addr), amount);
  }

  /// >>>>>>>>>>>>>>>>  BLOCK MANIPULATION TESTS  <<<<<<<<<<<<<<<<< ///

  function testGetBlockNumberAfterRoll() public {
    vm.roll(12345678);
    assertEq(multicall.getBlockNumber(), 12345678);
  }

  function testGetCurrentBlockTimestampAfterWarp() public {
    vm.warp(1_700_000_000);
    assertEq(multicall.getCurrentBlockTimestamp(), 1_700_000_000);
  }

  function testGetCurrentBlockCoinbaseAfterSet() public {
    vm.coinbase(RECIPIENT);
    assertEq(multicall.getCurrentBlockCoinbase(), RECIPIENT);
  }

  function testGetLastBlockHashAfterRoll() public {
    vm.roll(100);
    assertEq(multicall.getLastBlockHash(), blockhash(99));
  }

  /// >>>>>>>>>>>>>>>>>>>>>  FUZZ TESTS  <<<<<<<<<<<<<<<<<<<<<<<<< ///

  function testFuzzAggregateSingleSuccessCall(uint256 blockNum) public {
    Multicall3.Call[] memory calls = new Multicall3.Call[](1);
    calls[0] = Multicall3.Call(address(callee), abi.encodeWithSignature("getBlockHash(uint256)", blockNum));
    (uint256 returnedBlock, bytes[] memory returnData) = multicall.aggregate(calls);
    assertEq(returnedBlock, block.number);
    assertEq(keccak256(returnData[0]), keccak256(abi.encodePacked(blockhash(blockNum))));
  }

  function testFuzzTryAggregateAllowFailure(uint8 numCalls) public {
    // Build an array of calls that all succeed, verify lengths match
    uint256 len = uint256(numCalls);
    Multicall3.Call[] memory calls = new Multicall3.Call[](len);
    for (uint256 i = 0; i < len; i++) {
      calls[i] = Multicall3.Call(address(multicall), abi.encodeWithSignature("getBlockNumber()"));
    }
    Multicall3.Result[] memory results = multicall.tryAggregate(false, calls);
    assertEq(results.length, len);
    for (uint256 i = 0; i < len; i++) {
      assertTrue(results[i].success);
      assertEq(abi.decode(results[i].returnData, (uint256)), block.number);
    }
  }

  function testFuzzAggregate3AllowAllFailure(uint8 numCalls) public {
    uint256 len = uint256(numCalls);
    Multicall3.Call3[] memory calls = new Multicall3.Call3[](len);
    for (uint256 i = 0; i < len; i++) {
      calls[i] = Multicall3.Call3(address(multicall), true, abi.encodeWithSignature("getBlockNumber()"));
    }
    Multicall3.Result[] memory results = multicall.aggregate3(calls);
    assertEq(results.length, len);
    for (uint256 i = 0; i < len; i++) {
      assertTrue(results[i].success);
    }
  }

  /// >>>>>>>>>>>>>>>>>>>>>>  HELPER TESTS  <<<<<<<<<<<<<<<<<<<<<<< ///

  function testGetBlockHash(uint256 blockNumber) public {
    assertEq(blockhash(blockNumber), multicall.getBlockHash(blockNumber));
  }

  function testGetBlockNumber() public {
    assertEq(block.number, multicall.getBlockNumber());
  }

  function testGetCurrentBlockCoinbase() public {
    assertEq(block.coinbase, multicall.getCurrentBlockCoinbase());
  }

  function testGetCurrentBlockDifficulty() public {
    assertEq(block.difficulty, multicall.getCurrentBlockDifficulty());
  }

  function testGetCurrentBlockGasLimit() public {
    assertEq(block.gaslimit, multicall.getCurrentBlockGasLimit());
  }

  function testGetCurrentBlockTimestamp() public {
    assertEq(block.timestamp, multicall.getCurrentBlockTimestamp());
  }

  function testGetEthBalance(address addr) public {
    assertEq(addr.balance, multicall.getEthBalance(addr));
  }

  function testGetLastBlockHash() public {
    // Prevent arithmetic underflow on the genesis block
    if (block.number == 0) return;
    assertEq(blockhash(block.number - 1), multicall.getLastBlockHash());
  }

  function testGetBasefee() public {
    assertEq(block.basefee, multicall.getBasefee());
  }

  function testGetChainId() public {
    assertEq(block.chainid, multicall.getChainId());
  }
}
