// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;


import "./Insurance.sol";


contract DecentralizedInsurance {
    
    // Structures

    struct Policy {
        address policyholder;
        uint256 premiumAmount;
        uint256 coverageAmount;
        uint256 startDate;
        uint256 endDate;
        uint256 delinquencyCount;
        uint256 claimCount;
        bool isActive;
    }

    struct Claim {
        uint256 policyId;
        address claimant;
        uint256 claimAmount;
        bytes claimDescription;
        uint256 dateSubmitted;
        ClaimStatus status;
    }

    enum ClaimStatus {
        Submitted,
        UnderReview,
        Approved,
        Denied,
        Paid
    }

    enum DelinquencyAction {
        NotDelinquent,
        LessDelinquent,
        MoreDelinquent
    }

    // State variables
    address public owner;
    mapping(uint256 => uint8) public policyStatuses;  // policyId => PolicyStatus. Amount is the amount of delinquencies
    mapping(uint256 => Policy) public policies;  // policyId => Policy
    mapping(uint256 => Claim) public claims; // claimId => Claim
    uint8 delinquencyThreshold;  // Amount of delinquencies before a policy is cancelled
    Insurance public tokenAddress;
    uint256 public latestPolicyId = 0;
    uint256 public latestClaimId = 0;

    constructor(
        address _tokenAddress,
        uint8 _delinquencyThreshold
    ) {
        owner = msg.sender;
        tokenAddress = Insurance(_tokenAddress);
        delinquencyThreshold = _delinquencyThreshold;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    // Functions
    function issuePolicy(
        address _policyholder,
        uint256 _premiumAmount,
        uint256 _coverageAmount,
        uint256 _durationInDays
    ) public onlyOwner returns (uint256) {

        latestPolicyId += 1;

        policies[latestPolicyId] = Policy({
            policyholder: _policyholder,
            premiumAmount: _premiumAmount,
            coverageAmount: _coverageAmount,
            startDate: block.timestamp,
            endDate: block.timestamp + _durationInDays * 1 days,
            delinquencyCount: 0,
            claimCount: 0,
            isActive: true
        });

        return latestPolicyId;
    }

    function editDelinquencies(
        uint256 _policyId, 
        DelinquencyAction action
    ) public onlyOwner {
        Policy storage policy = policies[_policyId];
        require(policy.isActive, "Policy is not active");

        if (action == DelinquencyAction.NotDelinquent) {
            policy.delinquencyCount = 0;
        } else if (action == DelinquencyAction.LessDelinquent) {
            policy.delinquencyCount -= 1;
        } else if (action == DelinquencyAction.MoreDelinquent) {
            policy.delinquencyCount += 1;
        }

        if (policy.delinquencyCount >= delinquencyThreshold) {
            policy.isActive = false;
        }
    }
    function submitClaim(
        uint256 _policyId,
        uint256 _claimAmount,
        bytes memory _claimDescription
    ) public returns (uint256) {
        Policy storage policy = policies[_policyId];
        require(policy.isActive, "Policy is not active");
        // require(policy.policyholder == msg.sender, "Only the policyholder can submit a claim");

        latestClaimId += 1;
        policy.claimCount += 1; // placed here on submission. can be removed in claim is rejected

        claims[latestClaimId] = Claim({
            policyId: _policyId,
            claimant: msg.sender,
            claimAmount: _claimAmount,
            claimDescription: _claimDescription,
            dateSubmitted: block.timestamp,
            status: ClaimStatus.Submitted
        });

        return latestClaimId;
    }

    // Placeholder for approval function
    function reviewClaim(
        uint256 _claimId,
        bool isRejected
    ) public onlyOwner {
        // This function would contain logic for approving claims
        Claim storage claim = claims[_claimId];
        require(claim.status == ClaimStatus.Submitted, "Claim is not submitted");
        if (isRejected) {
            claim.status = ClaimStatus.Denied;
            Policy storage policy = policies[claim.policyId];
            if (policy.claimCount > 0) {
                policy.claimCount -= 1;
            }

            return;  // we early return here to avoid the rest of the function (which would have the claim under review)
        }

        claim.status = ClaimStatus.UnderReview;
        // For instance, reducing the coverageAmount if needed
    }

    function claimDecision(
        uint _claimId,
        ClaimStatus _status
    ) public onlyOwner {
        Claim storage claim = claims[_claimId];
        require(claim.status == ClaimStatus.UnderReview, "Claim is not under review");

        claim.status = _status;
        if (_status == ClaimStatus.Approved) {
            // pay the claimant the claim amount
            tokenAddress.transfer(claim.claimant, claim.claimAmount);
            claim.status = ClaimStatus.Paid;
        } else if (_status == ClaimStatus.Denied) {
            Policy storage policy = policies[claim.policyId];
            if (policy.claimCount > 0) {
                policy.claimCount -= 1;
            }
        }
    }

    // ... other necessary functions for managing claims and policies

}
