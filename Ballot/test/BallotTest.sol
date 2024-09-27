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
    uint256 private constant VOTING_DURATION = 60 minutes;
    uint256 private constant WEIGHT_SETTING_DURATION = 30 minutes;
    uint256 private constant PROPOSAL_COUNT = 3;
    uint256 private constant DEFAULT_WEIGHT = 1;
    uint256 private constant CUSTOM_WEIGHT = 2;
    uint256 private constant HIGH_WEIGHT = 3;

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

    // 测试初始状态
    function testInitialState() public view {
        assertEq(ballot.chairperson(), chairperson);
        assertEq(ballot.startTime(), block.timestamp);
        assertEq(ballot.endTime(), block.timestamp + VOTING_DURATION);
        assertEq(
            ballot.weightSettingEndTime(),
            block.timestamp + WEIGHT_SETTING_DURATION
        );
    }

    // 测试授予投票权
    function testGiveRightToVote() public {
        ballot.giveRightToVote(voter1);
        (uint256 weight, bool voted, address delegate, uint256 vote) = ballot
            .voters(voter1);
        assertEq(weight, DEFAULT_WEIGHT);
        assertEq(voted, false);
        assertEq(delegate, address(0));
        assertEq(vote, 0);
    }

    // 测试只有主席可以授予投票权
    function testOnlyChairpersonCanGiveRightToVote() public {
        vm.prank(voter1);
        vm.expectRevert(Ballot.Ballot__OnlyChairperson.selector);
        ballot.giveRightToVote(voter2);
    }

    // 测试设置选民权重
    function testSetVoterWeight() public {
        ballot.setVoterWeight(voter1, CUSTOM_WEIGHT);
        (uint256 weight, , , ) = ballot.voters(voter1);
        assertEq(weight, CUSTOM_WEIGHT);
    }

    // 测试不能在截日期后设置权重
    function testCannotSetWeightAfterDeadline() public {
        vm.warp(block.timestamp + WEIGHT_SETTING_DURATION + 1 minutes);
        vm.expectRevert(Ballot.Ballot__WeightSettingEnded.selector);
        ballot.setVoterWeight(voter1, CUSTOM_WEIGHT);
    }

    // 测试不能设置零权重
    function testCannotSetZeroWeight() public {
        vm.expectRevert(Ballot.Ballot__InvalidWeight.selector);
        ballot.setVoterWeight(voter1, 0);
    }

    // 测试不能为已投票的选民设置权重
    function testCannotSetWeightForVotedVoter() public {
        ballot.giveRightToVote(voter1);

        vm.prank(voter1);
        ballot.vote(0);

        vm.expectRevert(Ballot.Ballot__AlreadyVoted.selector);
        ballot.setVoterWeight(voter1, CUSTOM_WEIGHT);
    }

    // 测试委托投票
    function testDelegate() public {
        ballot.giveRightToVote(voter1);
        ballot.giveRightToVote(voter2);

        vm.prank(voter1);
        ballot.delegate(voter2);

        (uint256 weight, bool voted, address delegate, ) = ballot.voters(
            voter1
        );
        assertEq(weight, DEFAULT_WEIGHT);
        assertEq(voted, true);
        assertEq(delegate, voter2);

        (uint256 weight2, , , ) = ballot.voters(voter2);
        assertEq(weight2, CUSTOM_WEIGHT);
    }

    // 测试不能委托给自己
    function testCannotDelegateToSelf() public {
        ballot.giveRightToVote(voter1);

        vm.prank(voter1);
        vm.expectRevert(Ballot.Ballot__SelfDelegationNotAllowed.selector);
        ballot.delegate(voter1);
    }

    // 测试投票后不能委托
    function testCannotDelegateAfterVoting() public {
        ballot.giveRightToVote(voter1);
        ballot.giveRightToVote(voter2);

        vm.prank(voter1);
        ballot.vote(0);

        vm.prank(voter1);
        vm.expectRevert(Ballot.Ballot__AlreadyVoted.selector);
        ballot.delegate(voter2);
    }

    // 测试不能委托给没有投票权的人
    function testCannotDelegateToNonVoter() public {
        ballot.giveRightToVote(voter1);

        vm.prank(voter1);
        vm.expectRevert(Ballot.Ballot__DelegateHasNoVotingRights.selector);
        ballot.delegate(voter2);
    }

    // 测试投票
    function testVote() public {
        ballot.giveRightToVote(voter1);

        vm.prank(voter1);
        ballot.vote(0);

        (uint256 weight, bool voted, , uint256 vote) = ballot.voters(voter1);
        assertEq(weight, DEFAULT_WEIGHT);
        assertEq(voted, true);
        assertEq(vote, 0);

        (, uint256 voteCount) = ballot.proposals(0);
        assertEq(voteCount, 1);
    }

    // 测试不能在开始前投票
    function testCannotVoteBeforeStart() public {
        ballot.giveRightToVote(voter1);

        vm.warp(ballot.startTime() - 1);
        vm.prank(voter1);
        vm.expectRevert(Ballot.Ballot__VotingNotStarted.selector);
        ballot.vote(0);
    }

    // 测试不能在结束后投票
    function testCannotVoteAfterEnd() public {
        ballot.giveRightToVote(voter1);

        vm.warp(block.timestamp + VOTING_DURATION + 1 minutes);
        vm.prank(voter1);
        vm.expectRevert(Ballot.Ballot__VotingEnded.selector);
        ballot.vote(0);
    }

    // 测试不能投票两次
    function testCannotVoteTwice() public {
        ballot.giveRightToVote(voter1);

        vm.prank(voter1);
        ballot.vote(0);

        vm.prank(voter1);
        vm.expectRevert(Ballot.Ballot__AlreadyVoted.selector);
        ballot.vote(1);
    }

    // 测试没有投票权不能投票
    function testCannotVoteWithoutRights() public {
        vm.prank(voter1);
        vm.expectRevert(Ballot.Ballot__NoVotingRights.selector);
        ballot.vote(0);
    }

    // 测试获胜提案
    function testWinningProposal() public {
        ballot.giveRightToVote(voter1);
        ballot.giveRightToVote(voter2);
        ballot.setVoterWeight(voter3, HIGH_WEIGHT);

        vm.prank(voter1);
        ballot.vote(0);

        vm.prank(voter2);
        ballot.vote(1);

        vm.prank(voter3);
        ballot.vote(1);

        assertEq(ballot.winningProposal(), 1);
    }

    // 测试获胜提案名称
    function testWinnerName() public {
        ballot.giveRightToVote(voter1);
        ballot.giveRightToVote(voter2);
        ballot.setVoterWeight(voter3, HIGH_WEIGHT);

        vm.prank(voter1);
        ballot.vote(0);

        vm.prank(voter2);
        ballot.vote(1);

        vm.prank(voter3);
        ballot.vote(1);

        assertEq(ballot.winnerName(), "Proposal 2");
    }

    // 测试设置选民权重模糊测试
    function testFuzzSetVoterWeight(address voter, uint256 weight) public {
        vm.assume(
            voter != address(0) && weight > 0 && weight < type(uint256).max
        );

        ballot.setVoterWeight(voter, weight);
        (uint256 actualWeight, , , ) = ballot.voters(voter);
        assertEq(actualWeight, weight);
    }

    // 测试投票模糊测试
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

    // 测试委托模糊测试
    function testFuzzDelegate(address voter, address delegate) public {
        vm.assume(
            voter != address(0) && delegate != address(0) && voter != delegate
        );

        ballot.giveRightToVote(voter);
        ballot.giveRightToVote(delegate);

        vm.prank(voter);
        ballot.delegate(delegate);

        (, bool voterVoted, address voterDelegate, ) = ballot.voters(voter);
        (uint256 delegateWeight, , , ) = ballot.voters(delegate);

        assertEq(voterVoted, true);
        assertEq(voterDelegate, delegate);
        assertEq(delegateWeight, 2); // 假设默认权重为1
    }

    // 测试获胜提案模糊测试
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
        assertEq(
            winningVoteCount,
            maxVotes,
            "Winning proposal does not have the maximum votes"
        );

        // 检查实际获胜提案是否是有效的获胜提案之一
        (, uint256 expectedVoteCount) = ballot.proposals(
            expectedWinningProposal
        );
        assertEq(
            expectedVoteCount,
            maxVotes,
            "Expected winning proposal does not have the maximum votes"
        );
    }

    // 测试获胜提案模糊测试
    function testTieBreaker() public {
        ballot.giveRightToVote(voter1);
        ballot.giveRightToVote(voter2);

        vm.prank(voter1);
        ballot.vote(0);

        vm.prank(voter2);
        ballot.vote(1);

        uint256 winningProposal = ballot.winningProposal();
        (, uint256 winningVotes) = ballot.proposals(winningProposal);

        assertTrue(
            winningProposal == 0 || winningProposal == 1,
            "Winning proposal should be either 0 or 1"
        );
        assertEq(winningVotes, 1, "Winning proposal should have 1 vote");
    }
}
