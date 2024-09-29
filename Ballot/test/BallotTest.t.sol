// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/Ballot.sol";

contract BallotTest is Test {
    Ballot public ballot;

    address public chairperson;
    address public voter1;
    address public voter2;
    address public voter3;

    bytes32[] public proposalNames;

    // 定义常量
    uint256 private constant VOTING_DURATION = 60 minutes; // 投票持续时间
    uint256 private constant WEIGHT_SETTING_DURATION = 30 minutes; // 权重设置持续时间
    uint256 private constant PROPOSAL_COUNT = 3; // 提案数量
    uint256 private constant DEFAULT_WEIGHT = 1; // 默认投票权重
    uint256 private constant CUSTOM_WEIGHT = 2; // 自定义投票权重
    uint256 private constant HIGH_WEIGHT = 3; // 高投票权重

    function setUp() public {
        chairperson = address(this);
        voter1 = makeAddr("voter1");
        voter2 = makeAddr("voter2");
        voter3 = makeAddr("voter3");

        proposalNames = new bytes32[](PROPOSAL_COUNT);
        proposalNames[0] = "Proposal 1";
        proposalNames[1] = "Proposal 2";
        proposalNames[2] = "Proposal 3";

        ballot = new Ballot(
            proposalNames,
            VOTING_DURATION / 1 minutes,
            WEIGHT_SETTING_DURATION / 1 minutes
        );
    }

    function testInitialState() public view {
        assertEq(ballot.chairperson(), chairperson);
        assertEq(ballot.startTime(), block.timestamp);
        assertEq(ballot.endTime(), block.timestamp + VOTING_DURATION);
        assertEq(
            ballot.weightSettingEndTime(),
            block.timestamp + WEIGHT_SETTING_DURATION
        );
    }

    function testGiveRightToVote() public {
        ballot.giveRightToVote(voter1);
        (uint256 weight, bool voted, address delegate, uint256 vote) = ballot
            .voters(voter1);
        assertEq(weight, DEFAULT_WEIGHT);
        assertEq(voted, false);
        assertEq(delegate, address(0));
        assertEq(vote, 0);
    }

    function testOnlyChairpersonCanGiveRightToVote() public {
        vm.prank(voter1);
        vm.expectRevert(Ballot.Ballot__OnlyChairperson.selector);
        ballot.giveRightToVote(voter2);
    }

    function testSetVoterWeight() public {
        ballot.setVoterWeight(voter1, CUSTOM_WEIGHT);
        (uint256 weight, , , ) = ballot.voters(voter1);
        assertEq(weight, CUSTOM_WEIGHT);
    }

    function testSetWeightDuringAndAfterWeightSettingPeriod() public {
        ballot.setVoterWeight(voter1, CUSTOM_WEIGHT);
        (uint256 weight, , , ) = ballot.voters(voter1);
        assertEq(weight, CUSTOM_WEIGHT);

        vm.warp(block.timestamp + WEIGHT_SETTING_DURATION + 1 minutes);
        vm.expectRevert(Ballot.Ballot__WeightSettingEnded.selector);
        ballot.setVoterWeight(voter2, CUSTOM_WEIGHT);
    }

    function testCannotSetZeroWeight() public {
        vm.expectRevert(Ballot.Ballot__InvalidWeight.selector);
        ballot.setVoterWeight(voter1, 0);
    }

    function testCannotSetWeightForVotedVoter() public {
        ballot.giveRightToVote(voter1);

        vm.prank(voter1);
        ballot.vote(0);

        vm.expectRevert(Ballot.Ballot__AlreadyVoted.selector);
        ballot.setVoterWeight(voter1, CUSTOM_WEIGHT);
    }

    function testFuzzSetVoterWeight(address voter, uint256 weight) public {
        vm.assume(
            voter != address(0) && weight > 0 && weight < type(uint256).max
        );

        ballot.setVoterWeight(voter, weight);
        (uint256 actualWeight, , , ) = ballot.voters(voter);
        assertEq(actualWeight, weight);
    }

    function testFuzzVote(address voter, uint8 proposalIndex) public {
        vm.assume(voter != address(0) && proposalIndex < PROPOSAL_COUNT);

        ballot.giveRightToVote(voter);

        vm.prank(voter);
        ballot.vote(proposalIndex);

        (uint256 weight, bool voted, , uint256 vote) = ballot.voters(voter);
        assertEq(voted, true);
        assertEq(vote, proposalIndex);

        (, uint256 voteCount) = ballot.proposals(proposalIndex);
        assertEq(voteCount, weight);
    }

    // 测试复杂的委托场景
    function testFuzzDelegate(address voter, address delegate) public {
        vm.assume(
            voter != address(0) && delegate != address(0) && voter != delegate
        );

        // 确保voter和delegate都没有投票权
        (uint256 voterWeight, , , ) = ballot.voters(voter);
        (uint256 delegateWeight, , , ) = ballot.voters(delegate);
        vm.assume(voterWeight == 0);
        vm.assume(delegateWeight == 0);

        ballot.giveRightToVote(voter);
        ballot.giveRightToVote(delegate);

        vm.prank(voter);
        ballot.delegate(delegate);

        (, bool voterVoted, address voterDelegate, ) = ballot.voters(voter);
        (delegateWeight, , , ) = ballot.voters(delegate);

        assertEq(voterVoted, true);
        assertEq(voterDelegate, delegate);
        assertEq(delegateWeight, DEFAULT_WEIGHT + DEFAULT_WEIGHT);
    }

    // 测试多种投票情况下的获胜提案
    function testFuzzWinningProposal(uint256[] memory votes) public {
        vm.assume(votes.length == PROPOSAL_COUNT);

        uint256 maxVotes = 0;
        uint256 expectedWinningProposal = 0;

        for (uint i = 0; i < votes.length; i++) {
            votes[i] = votes[i] % 100; // 限制投票数量，避免溢出
            for (uint j = 0; j < votes[i]; j++) {
                address voter = address(uint160(i * 100 + j + 1));
                ballot.giveRightToVote(voter);
                vm.prank(voter);
                ballot.vote(i);
            }

            // 更新预期的获胜提案
            if (votes[i] >= maxVotes) {
                maxVotes = votes[i];
                expectedWinningProposal = i;
            }
        }

        uint256 actualWinningProposal = ballot.winningProposal();

        // 检查实际获胜提案的票数是否等于最高票数
        (, uint256 winningVoteCount) = ballot.proposals(actualWinningProposal);
        assertEq(winningVoteCount, maxVotes);

        // 检查实际获胜提案是否是有效的获胜提案之一
        (, uint256 expectedVoteCount) = ballot.proposals(
            expectedWinningProposal
        );
        assertEq(expectedVoteCount, maxVotes);
    }

    // 测试平局情况下的获胜提案
    function testTieBreaker() public {
        ballot.giveRightToVote(voter1);
        ballot.giveRightToVote(voter2);

        vm.prank(voter1);
        ballot.vote(0);

        vm.prank(voter2);
        ballot.vote(1);

        uint256 winningProposal = ballot.winningProposal();
        (, uint256 winningVotes) = ballot.proposals(winningProposal);

        assertTrue(winningProposal == 0 || winningProposal == 1);
        assertEq(winningVotes, 1);
    }

    // 测试获取投票状态
    function testGetVotingStatus() public {
        assertEq(ballot.getVotingStatus(), 1); // 刚开始应该是进行中

        // 测试未开始状态
        vm.warp(ballot.startTime() - 1);
        assertEq(ballot.getVotingStatus(), 0); // 未开始

        // 测试进行中状态
        vm.warp(ballot.startTime() + 1 minutes);
        assertEq(ballot.getVotingStatus(), 1); // 进行中

        // 测试已结束状态
        vm.warp(ballot.endTime() + 1);
        assertEq(ballot.getVotingStatus(), 2); // 已结束
    }

    // 测试委托给已投票的选民
    function testDelegateToVotedVoter() public {
        ballot.giveRightToVote(voter1);
        ballot.giveRightToVote(voter2);

        vm.prank(voter2);
        ballot.vote(0);

        vm.prank(voter1);
        ballot.delegate(voter2);

        (, uint256 voteCount) = ballot.proposals(0);
        assertEq(voteCount, 2); // voter2的票 + voter1委托的票
    }

    // 测试委托链
    function testDelegationChain() public {
        ballot.giveRightToVote(voter1);
        ballot.giveRightToVote(voter2);
        ballot.giveRightToVote(voter3);

        vm.prank(voter1);
        ballot.delegate(voter2);

        vm.prank(voter2);
        ballot.delegate(voter3);

        vm.prank(voter3);
        ballot.vote(1);

        (, uint256 voteCount) = ballot.proposals(1);
        assertEq(voteCount, 3); // voter1 + voter2 + voter3 的票
    }

    // 测试投票给不存在的提案
    function testVoteForNonExistentProposal() public {
        ballot.giveRightToVote(voter1);

        vm.prank(voter1);
        vm.expectRevert(Ballot.Ballot__InvalidProposal.selector);
        ballot.vote(PROPOSAL_COUNT); // 尝试为不存在的提案投票
    }

    // 测试当所有提案得票为0时的获胜提案
    function testWinningProposalWhenAllZeroVotes() public view {
        assertEq(ballot.winningProposal(), 0); // 应该返回第一个提案
    }

    // 测试委托给已经委托给其他人的选民
    function testDelegateToAlreadyDelegatedVoter() public {
        ballot.giveRightToVote(voter1);
        ballot.giveRightToVote(voter2);
        ballot.giveRightToVote(voter3);

        vm.prank(voter2);
        ballot.delegate(voter3);

        vm.prank(voter1);
        ballot.delegate(voter2);

        (, uint256 voteCount) = ballot.proposals(0);
        assertEq(voteCount, 0);

        vm.prank(voter3);
        ballot.vote(0);

        (, voteCount) = ballot.proposals(0);
        assertEq(voteCount, 3); // voter1 + voter2 + voter3 的票
    }

    // 测试在投票期间尝试设置权重
    function testSetWeightDuringVoting() public {
        // 移动时间到权重设置期结束后，但仍在投票期间
        vm.warp(ballot.weightSettingEndTime() + 1);

        // 确保我们仍在投票期间
        require(block.timestamp <= ballot.endTime(), "Not in voting period");

        // 尝试设置权重，应该失败
        vm.expectRevert(Ballot.Ballot__WeightSettingEnded.selector);
        ballot.setVoterWeight(voter1, CUSTOM_WEIGHT);
    }

    // 测试主席尝试给自己投票权
    function testChairpersonGiveRightToSelf() public {
        vm.expectRevert(Ballot.Ballot__HasVotingRights.selector);
        ballot.giveRightToVote(chairperson);
    }

    // 测试当所有提案票数相同时的获胜提案
    function testWinningProposalWithEqualVotes() public {
        ballot.giveRightToVote(voter1);
        ballot.giveRightToVote(voter2);
        ballot.giveRightToVote(voter3);

        vm.prank(voter1);
        ballot.vote(0);

        vm.prank(voter2);
        ballot.vote(1);

        vm.prank(voter3);
        ballot.vote(2);

        uint256 winningProposal = ballot.winningProposal();
        assertEq(winningProposal, 0); // 应该返回第一个提案
    }

    // 测试在投票结束后尝试投票
    function testVoteAfterVotingEnded() public {
        ballot.giveRightToVote(voter1);
        vm.warp(ballot.endTime() + 1);

        vm.prank(voter1);
        vm.expectRevert(Ballot.Ballot__VotingEnded.selector);
        ballot.vote(0);
    }

    // 测试重复授予投票权
    function testGiveRightToVoteRepeatedly() public {
        ballot.giveRightToVote(voter1);
        vm.expectRevert(Ballot.Ballot__HasVotingRights.selector);
        ballot.giveRightToVote(voter1);
    }
}
