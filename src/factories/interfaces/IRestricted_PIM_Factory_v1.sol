// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity ^0.8.0;

// Internal Interfaces
import {IOrchestrator_v1} from
    "src/orchestrator/interfaces/IOrchestrator_v1.sol";
import {IOrchestratorFactory_v1} from
    "src/factories/interfaces/IOrchestratorFactory_v1.sol";
import {IBondingCurveBase_v1} from
    "@fm/bondingCurve/interfaces/IBondingCurveBase_v1.sol";

// Internal Dependencies
import {ERC20Issuance_v1} from "src/external/token/ERC20Issuance_v1.sol";

interface IRestricted_PIM_Factory_v1 {
    //--------------------------------------------------------------------------
    // Errors
    error InsufficientFunding(uint availableFunding);

    //--------------------------------------------------------------------------
    // Events

    /// @notice Event emitted when a new PIM workflow is created.
    /// @param orchestrator The address of the orchestrator.
    /// @param issuanceToken The address of the issuance token.
    /// @param deployer The address of the deployer.
    event PIMWorkflowCreated(
        address indexed orchestrator,
        address indexed issuanceToken,
        address indexed deployer
    );

    /// @notice Event emitted when new funding is added.
    /// @param paymaster Address that pays funding.
    /// @param actor Address that can use new funding.
    /// @param token Address of token used for funding.
    /// @param amount Funding amount.
    event FundingAdded(
        address indexed paymaster,
        address indexed actor,
        address indexed token,
        uint amount
    );

    /// @notice Event emitted when existing funding is removed.
    /// @param paymaster Address that agreed to pay for funding.
    /// @param actor Address that could have used the funding.
    /// @param token Address of token used that would have been used for funding.
    /// @param amount Funding amount.
    event FundingRemoved(
        address indexed paymaster,
        address indexed actor,
        address indexed token,
        uint amount
    );

    //--------------------------------------------------------------------------
    // Functions

    /// @notice Deploys a new issuance token and uses that to deploy a workflow with restricted bonding curve.
    /// @param workflowConfig The workflow's config data.
    /// @param fundingManagerConfig The config data for the orchestrator's {IFundingManager_v1} instance.
    /// @param authorizerConfig The config data for the orchestrator's {IAuthorizer_v1} instance.
    /// @param paymentProcessorConfig The config data for the orchestrator's {IPaymentProcessor_v1} instance.
    /// @param moduleConfigs Variable length set of optional module's config data.
    /// @param issuanceTokenParams The issuance token's parameters (name, symbol, decimals, maxSupply).
    /// @return CreatedOrchestrator Returns the created orchestrator instance.
    function createPIMWorkflow(
        IOrchestratorFactory_v1.WorkflowConfig memory workflowConfig,
        IOrchestratorFactory_v1.ModuleConfig memory fundingManagerConfig,
        IOrchestratorFactory_v1.ModuleConfig memory authorizerConfig,
        IOrchestratorFactory_v1.ModuleConfig memory paymentProcessorConfig,
        IOrchestratorFactory_v1.ModuleConfig[] memory moduleConfigs,
        IBondingCurveBase_v1.IssuanceToken memory issuanceTokenParams
    ) external returns (IOrchestrator_v1);
}
