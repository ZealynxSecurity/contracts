// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity ^0.8.0;

import "forge-std/console.sol";

// Internal Dependencies
import {Module_v1} from "src/modules/base/Module_v1.sol";
import {
    E2ETest,
    IOrchestratorFactory_v1,
    IOrchestrator_v1
} from "test/e2e/E2ETest.sol";
// Uniswap Dependencies
import {IUniswapV2Factory} from "@unicore/interfaces/IUniswapV2Factory.sol";
import {IUniswapV2Pair} from "@unicore/interfaces/IUniswapV2Pair.sol";
import {IUniswapV2Router02} from "@uniperi/interfaces/IUniswapV2Router02.sol";
import {UniswapV2Factory} from "@unicore/UniswapV2Factory.sol";
import {UniswapV2Router02} from "@uniperi/UniswapV2Router02.sol";
import {WETH9} from "@uniperi/test/WETH9.sol";
// SuT
import {
    FM_BC_Bancor_Redeeming_VirtualSupply_v1,
    IFM_BC_Bancor_Redeeming_VirtualSupply_v1
} from "@fm/bondingCurve/FM_BC_Bancor_Redeeming_VirtualSupply_v1.sol";
import {
    LM_PC_MigrateLiquidity_UniswapV2_v1,
    ILM_PC_MigrateLiquidity_UniswapV2_v1
} from "@lm/LM_PC_MigrateLiquidity_UniswapV2_v1.sol";
import {FM_Rebasing_v1} from "@fm/rebasing/FM_Rebasing_v1.sol";
import {ERC165Upgradeable} from
    "@oz-up/utils/introspection/ERC165Upgradeable.sol";
import {ERC20Issuance_v1} from "src/external/token/ERC20Issuance_v1.sol";

contract MigrateLiquidityE2ETest is E2ETest {
    // Module Configurations
    IOrchestratorFactory_v1.ModuleConfig[] moduleConfigurations;

    // Uniswap contracts
    UniswapV2Factory uniswapFactory;
    UniswapV2Router02 uniswapRouter;
    WETH9 weth;

    // Constants
    uint constant COLLATERAL_MIGRATION_THRESHOLD = 1000e18;
    uint constant COLLATERAL_MIGRATION_AMOUNT = 1000e18;
    ERC20Issuance_v1 issuanceToken;

    function setUp() public override {
        //--------------------------------------------------------------------------
        // Setup
        //--------------------------------------------------------------------------

        // Setup common E2E framework
        super.setUp();

        // Deploy Uniswap contracts
        weth = new WETH9();
        uniswapFactory = new UniswapV2Factory(address(this));
        uniswapRouter =
            new UniswapV2Router02(address(uniswapFactory), address(weth));

        // Set Up Modules

        // FundingManager
        setUpBancorVirtualSupplyBondingCurveFundingManager();

        // BancorFormula 'formula' is instantiated in the E2EModuleRegistry

        issuanceToken = new ERC20Issuance_v1(
            "Bonding Curve Token", "BCT", 18, type(uint).max - 1, address(this)
        );

        IFM_BC_Bancor_Redeeming_VirtualSupply_v1.BondingCurveProperties memory
            bc_properties = IFM_BC_Bancor_Redeeming_VirtualSupply_v1
                .BondingCurveProperties({
                formula: address(formula),
                reserveRatioForBuying: 333_333,
                reserveRatioForSelling: 333_333,
                buyFee: 0,
                sellFee: 0,
                buyIsOpen: true,
                sellIsOpen: true,
                initialIssuanceSupply: 10,
                initialCollateralSupply: 30
            });

        moduleConfigurations.push(
            IOrchestratorFactory_v1.ModuleConfig(
                bancorVirtualSupplyBondingCurveFundingManagerMetadata,
                abi.encode(address(issuanceToken), bc_properties, token)
            )
        );

        // Authorizer
        setUpRoleAuthorizer();
        moduleConfigurations.push(
            IOrchestratorFactory_v1.ModuleConfig(
                roleAuthorizerMetadata, abi.encode(address(this))
            )
        );

        // PaymentProcessor
        setUpSimplePaymentProcessor();
        moduleConfigurations.push(
            IOrchestratorFactory_v1.ModuleConfig(
                simplePaymentProcessorMetadata, bytes("")
            )
        );

        // Migration Module
        setUpLM_PC_MigrateLiquidity_UniswapV2_v1();
        moduleConfigurations.push(
            IOrchestratorFactory_v1.ModuleConfig(
                LM_PC_MigrateLiquidity_UniswapV2_v1Metadata,
                abi.encode(
                    ILM_PC_MigrateLiquidity_UniswapV2_v1
                        .LiquidityMigrationConfig({
                        collateralMigrationAmount: COLLATERAL_MIGRATION_AMOUNT,
                        collateralMigrateThreshold: COLLATERAL_MIGRATION_THRESHOLD,
                        dexRouterAddress: address(uniswapRouter),
                        dexFactoryAddress: address(uniswapFactory),
                        closeBuyOnThreshold: true,
                        closeSellOnThreshold: false
                    })
                )
            )
        );
    }

    // Test
    function test_e2e_MigrateLiquidityLifecycle() public {
        //--------------------------------------------------------------------------
        // Orchestrator Initialization
        //--------------------------------------------------------------------------

        // Set WorkflowConfig
        IOrchestratorFactory_v1.WorkflowConfig memory workflowConfig =
        IOrchestratorFactory_v1.WorkflowConfig({
            independentUpdates: false,
            independentUpdateAdmin: address(0)
        });

        // Set Orchestrator
        IOrchestrator_v1 orchestrator =
            _create_E2E_Orchestrator(workflowConfig, moduleConfigurations);

        // Set FundingManager
        FM_BC_Bancor_Redeeming_VirtualSupply_v1 fundingManager =
        FM_BC_Bancor_Redeeming_VirtualSupply_v1(
            address(orchestrator.fundingManager())
        );

        // Find and Set Migration Manager
        LM_PC_MigrateLiquidity_UniswapV2_v1 migrationManager;
        address[] memory modulesList = orchestrator.listModules();
        for (uint i; i < modulesList.length; ++i) {
            if (
                ERC165Upgradeable(modulesList[i]).supportsInterface(
                    type(ILM_PC_MigrateLiquidity_UniswapV2_v1).interfaceId
                )
            ) {
                migrationManager =
                    LM_PC_MigrateLiquidity_UniswapV2_v1(modulesList[i]);
                break;
            }
        }

        // Test Lifecycle
        //--------------------------------------------------------------------------

        // 1. Set FundingManager as Minter
        issuanceToken.setMinter(address(fundingManager), true);
        // 1.1. Set Migration Manager As Minter
        issuanceToken.setMinter(address(migrationManager), true);
        // 2. Mint Collateral To Buy From the FundingManager
        token.mint(address(this), COLLATERAL_MIGRATION_AMOUNT);
        // 3. Calculate Minimum Amount Out
        uint buf_minAmountOut =
            fundingManager.calculatePurchaseReturn(COLLATERAL_MIGRATION_AMOUNT); // buffer variable to store the minimum amount out on calls to the buy and sell functions
        // 4. Buy from the FundingManager
        vm.startPrank(address(this));
        {
            // 4.1. Approve tokens to fundingManager.
            token.approve(address(fundingManager), COLLATERAL_MIGRATION_AMOUNT);
            // 4.2. Deposit tokens, i.e. fund the fundingmanager.
            fundingManager.buy(COLLATERAL_MIGRATION_AMOUNT, buf_minAmountOut);
            // 4.3. After the deposit, check that the user has received them
            assertTrue(
                issuanceToken.balanceOf(address(this)) > 0,
                "User should have received issuance tokens after deposit"
            );
        }
        vm.stopPrank();

        // 5. Verify Migration Manager configuration
        ILM_PC_MigrateLiquidity_UniswapV2_v1.LiquidityMigrationConfig memory
            migration = migrationManager.getMigrationConfig();

        bool executed = migrationManager.getExecuted();

        assertEq(
            migration.collateralMigrateThreshold,
            COLLATERAL_MIGRATION_THRESHOLD,
            "Collateral migration threshold mismatch"
        );
        assertEq(
            migration.dexRouterAddress,
            address(uniswapRouter),
            "Dex router address mismatch"
        );
        assertEq(
            migration.dexFactoryAddress,
            address(uniswapFactory),
            "Dex factory address mismatch"
        );
        assertTrue(
            migration.closeBuyOnThreshold, "Close buy on threshold mismatch"
        );
        assertFalse(
            migration.closeSellOnThreshold, "Close sell on threshold mismatch"
        );
        assertFalse(executed, "Migration should not be executed yet");
        // 6. Check no pool exists yet
        address pairAddress =
            uniswapFactory.getPair(address(token), address(weth));
        assertEq(pairAddress, address(0), "Pool should not exist yet");
        // 7. Execute migration
        vm.startPrank(address(this));
        migrationManager.executeMigration();
        vm.stopPrank();
        // 8. Verify pool creation and liquidity
        pairAddress = uniswapFactory.getPair(address(token), address(weth));
        assertTrue(pairAddress != address(0), "Pool should exist");
        // 8.1. Get pair
        IUniswapV2Pair pair = IUniswapV2Pair(pairAddress);
        // 8.2. Get reserves
        (uint112 reserve0, uint112 reserve1,) = pair.getReserves();
        // 8.3. Verify reserves based on token ordering
        if (pair.token0() == address(token)) {
            assertGt(reserve0, 0, "Token reserves should be positive");
            assertGt(reserve1, 0, "WETH reserves should be positive");
        } else {
            assertGt(reserve0, 0, "WETH reserves should be positive");
            assertGt(reserve1, 0, "Token reserves should be positive");
        }
        // 9. Verify migration completion
        migration = migrationManager.getMigrationConfig();
        assertTrue(executed, "Migration should be marked as executed");
    }
}
