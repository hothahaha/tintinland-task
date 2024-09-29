// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract Ballot {
    struct Voter {
        uint256 weight;
        bool voted;
        address delegate;
        uint256 vote;
    }

    struct Proposal {
        bytes32 name;
        uint256 voteCount;
    }

    address public immutable i_chairperson;
    mapping(address => Voter) public voters;
    Proposal[] public proposals;

    uint256 public immutable i_startTime; // 投票开始时间
    uint256 public immutable i_endTime; // 投票结束时间
    uint256 public immutable i_weightSettingEndTime; // 权重设置结束时间

    error Ballot__OnlyChairperson();
    error Ballot__AlreadyVoted();
    error Ballot__NoVotingRights();
    error Ballot__HasVotingRights();
    error Ballot__SelfDelegationNotAllowed();
    error Ballot__FoundLoopInDelegation();
    error Ballot__DelegateHasNoVotingRights();
    error Ballot__VotingNotStarted();
    error Ballot__VotingEnded();
    error Ballot__WeightSettingEnded();
    error Ballot__InvalidWeight();
    error Ballot__InvalidProposal();

    event VoterWeightSet(address indexed voter, uint256 weight);
    event Voted(address indexed voter, uint256 proposalIndex);
    event Delegated(address indexed from, address indexed to);

    /*
     * @dev 构造函数，初始化投票系统
     * @param proposalNames 提案名称数组
     * @param _durationInMinutes 投票持续时间（分钟）
     * @param _weightSettingDurationInMinutes 权重设置持续时间（分钟）
     */
    constructor(
        bytes32[] memory proposalNames,
        uint256 _durationInMinutes,
        uint256 _weightSettingDurationInMinutes
    ) {
        i_chairperson = msg.sender;
        voters[i_chairperson].weight = 1;

        for (uint256 i = 0; i < proposalNames.length; i++) {
            proposals.push(Proposal({name: proposalNames[i], voteCount: 0}));
        }

        i_startTime = block.timestamp;
        i_endTime = i_startTime + (_durationInMinutes * 1 minutes);
        i_weightSettingEndTime =
            i_startTime +
            (_weightSettingDurationInMinutes * 1 minutes);
    }

    /*
     * @dev 设置选民的投票权重
     * @param voter 选民地址
     * @param weight 要设置的权重
     */
    function setVoterWeight(address voter, uint256 weight) external {
        if (msg.sender != i_chairperson) revert Ballot__OnlyChairperson();
        if (block.timestamp > i_weightSettingEndTime)
            revert Ballot__WeightSettingEnded();
        if (weight == 0) revert Ballot__InvalidWeight();
        if (voters[voter].voted) revert Ballot__AlreadyVoted();

        voters[voter].weight = weight;
        emit VoterWeightSet(voter, weight);
    }

    /*
     * @dev 授予投票权
     * @param voter 要授予投票权的地址
     */
    function giveRightToVote(address voter) external {
        if (msg.sender != i_chairperson) revert Ballot__OnlyChairperson();
        if (voters[voter].voted) revert Ballot__AlreadyVoted();
        if (voters[voter].weight != 0) revert Ballot__HasVotingRights();

        voters[voter].weight = 1;
    }

    /*
     * @dev 委托投票权给其他地址
     * @param to 被委托人地址
     */
    function delegate(address to) external {
        Voter storage sender = voters[msg.sender];
        if (sender.weight == 0) revert Ballot__NoVotingRights();
        if (sender.voted) revert Ballot__AlreadyVoted();
        if (to == msg.sender) revert Ballot__SelfDelegationNotAllowed();

        while (voters[to].delegate != address(0)) {
            to = voters[to].delegate;
            if (to == msg.sender) revert Ballot__FoundLoopInDelegation();
        }

        Voter storage delegate_ = voters[to];
        if (delegate_.weight < 1) revert Ballot__DelegateHasNoVotingRights();

        sender.voted = true;
        sender.delegate = to;
        if (delegate_.voted) {
            proposals[delegate_.vote].voteCount += sender.weight;
        } else {
            delegate_.weight += sender.weight;
        }
        emit Delegated(msg.sender, to);
    }

    /*
     * @dev 进行投票
     * @param proposal 要投票的提案索引
     */
    function vote(uint256 proposal) external {
        if (block.timestamp < i_startTime) revert Ballot__VotingNotStarted();
        if (block.timestamp > i_endTime) revert Ballot__VotingEnded();
        if (proposal >= proposals.length) revert Ballot__InvalidProposal(); // 添加这行

        Voter storage sender = voters[msg.sender];
        if (sender.weight == 0) revert Ballot__NoVotingRights();
        if (sender.voted) revert Ballot__AlreadyVoted();

        sender.voted = true;
        sender.vote = proposal;
        proposals[proposal].voteCount += sender.weight;
        emit Voted(msg.sender, proposal);
    }

    /*
     * @dev 计算获胜提案
     * @return winningProposal_ 获胜提案的索引
     */
    function winningProposal() public view returns (uint256 winningProposal_) {
        uint256 winningVoteCount = 0;
        uint256 proposalsLength = proposals.length;
        for (uint256 p = 0; p < proposalsLength; p++) {
            if (proposals[p].voteCount > winningVoteCount) {
                winningVoteCount = proposals[p].voteCount;
                winningProposal_ = p;
            }
        }
    }

    /*
     * @dev 获取获胜提案的名称
     * @return winnerName_ 获胜提案的名称
     */
    function winnerName() external view returns (bytes32 winnerName_) {
        winnerName_ = proposals[winningProposal()].name;
    }

    /*
     * @dev 获取当前投票状态
     * @return status 0: 未开始, 1: 进行中, 2: 已结束
     */
    function getVotingStatus() public view returns (uint8 status) {
        if (block.timestamp < i_startTime) {
            return 0; // 未开始
        } else if (block.timestamp <= i_endTime) {
            return 1; // 进行中
        } else {
            return 2; // 已结束
        }
    }
}
