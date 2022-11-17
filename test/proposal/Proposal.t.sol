// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

// External Interfaces
import {IERC20} from "@oz/token/ERC20/IERC20.sol";

// Internal Dependencies
import {Proposal} from "src/proposal/Proposal.sol";

// Internal Interfaces
import {
    IProposal,
    IAuthorizer,
    IPaymentProcessor
} from "src/proposal/IProposal.sol";

// Mocks
import {AuthorizerMock} from "test/utils/mocks/AuthorizerMock.sol";
import {PaymentProcessorMock} from
    "test/utils/mocks/modules/PaymentProcessorMock.sol";
import {ERC20Mock} from "test/utils/mocks/ERC20Mock.sol";

// Errors
import {OZErrors} from "test/utils/errors/OZErrors.sol";

// Helper
import {TypeSanityHelper} from "test/proposal/helper/TypeSanityHelper.sol";

contract ProposalTest is Test {
    // SuT
    Proposal proposal;

    // Helper
    TypeSanityHelper types;

    // Mocks
    AuthorizerMock authorizer;
    PaymentProcessorMock paymentProcessor;
    ERC20Mock token;

    function setUp() public {
        authorizer = new AuthorizerMock();
        paymentProcessor = new PaymentProcessorMock();
        token = new ERC20Mock("TestToken", "TST");

        proposal = new Proposal();

        types = new TypeSanityHelper(address(proposal));
    }

    //--------------------------------------------------------------------------
    // Tests: Initialization

    function testInit(uint proposalId, address[] memory modules) public {
        types.assumeValidProposalId(proposalId);
        types.assumeValidModules(modules);

        // Make sure mock addresses are not in set of modules.
        types.assumeElemNotInSet(modules, address(authorizer));
        types.assumeElemNotInSet(modules, address(paymentProcessor));
        types.assumeElemNotInSet(modules, address(token));

        // Initialize proposal.
        proposal.init(
            proposalId,
            address(this),
            token,
            modules,
            authorizer,
            paymentProcessor
        );

        // Check that proposal's storage correctly initialized.
        assertEq(proposal.proposalId(), proposalId);
        assertEq(address(proposal.owner()), address(this));
        assertEq(address(proposal.token()), address(token));
        assertEq(address(proposal.authorizer()), address(authorizer));
        assertEq(
            address(proposal.paymentProcessor()), address(paymentProcessor)
        );

        // Check that proposal's dependencies correctly initialized.
        // Ownable:
        assertEq(proposal.owner(), address(this));
        // Pausable:
        assertTrue(!proposal.paused());
    }

    function testReinitFails(uint proposalId, address[] memory modules)
        public
    {
        types.assumeValidProposalId(proposalId);
        types.assumeValidModules(modules);

        // Make sure mock addresses are not in set of modules.
        types.assumeElemNotInSet(modules, address(authorizer));
        types.assumeElemNotInSet(modules, address(paymentProcessor));
        types.assumeElemNotInSet(modules, address(token));

        // Initialize proposal.
        proposal.init(
            proposalId,
            address(this),
            token,
            modules,
            authorizer,
            paymentProcessor
        );

        vm.expectRevert(OZErrors.Initializable__AlreadyInitialized);
        proposal.init(
            proposalId,
            address(this),
            token,
            modules,
            authorizer,
            paymentProcessor
        );
    }

    //--------------------------------------------------------------------------
    // Tests: Transaction Execution

    function testExecuteTx() public {
        // @todo mp: Add Proposal::executeTx tests.
    }

    //--------------------------------------------------------------------------
    // Tests: Other

    function testVersion() public {
        assertEq(proposal.version(), "1");
    }
}
