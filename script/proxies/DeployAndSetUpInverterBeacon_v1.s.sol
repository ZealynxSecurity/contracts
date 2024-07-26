pragma solidity ^0.8.0;

import "forge-std/Script.sol";

import {InverterBeacon_v1} from "src/proxies/InverterBeacon_v1.sol";
import {InverterBeaconProxy_v1} from "src/proxies/InverterBeaconProxy_v1.sol";
import {IModule_v1} from "src/modules/base/IModule_v1.sol";

import {ModuleFactory_v1} from "src/factories/ModuleFactory_v1.sol";

/**
 * @title DeployAndSetupInverterBeacon_v1 Deployment Script
 *
 * @dev Script to deploy and setup new InverterBeacon_v1.
 *
 *
 * @author Inverter Network
 */
contract DeployAndSetUpInverterBeacon_v1 is Script, ProtocolConstants {
    function deployBeaconAndSetupProxy(
        string memory implementationName,
        address reverter,
        address owner,
        address implementation,
        uint majorVersion,
        uint minorVersion,
        uint patchVersion
    ) external returns (address beaconAddress, address proxy) {
        // Deploy the beacon.
        beaconAddress = deployInverterBeacon(
            implementationName,
            reverter,
            owner,
            implementation,
            majorVersion,
            minorVersion,
            patchVersion
        );
        vm.startBroadcast(deployerPrivateKey);
        {
            // return the proxy after creation
            proxy = address(
                new InverterBeaconProxy_v1(InverterBeacon_v1(beaconAddress))
            );

            // cast to address for return
            //beaconAddress = address(beacon);
        }
        vm.stopBroadcast();

        console2.log(
            "Creation of InverterBeaconProxy_v1 for %s at address: %s",
            implementationName,
            address(proxy)
        );
    }

    function deployInverterBeacon(
        string memory implementationName,
        address reverter,
        address owner,
        address implementation,
        uint majorVersion,
        uint minorVersion,
        uint patchVersion
    ) public returns (address beacon) {
        vm.startBroadcast(deployerPrivateKey);
        {
            // Deploy the beacon.

            beacon = address(
                new InverterBeacon_v1(
                    reverter,
                    owner,
                    majorVersion,
                    implementation,
                    minorVersion,
                    patchVersion
                )
            );
        }

        vm.stopBroadcast();

        // Log the deployed Beacon contract address.
        console2.log(
            "Deployment of Inverter Beacon for %s at address %s",
            implementationName,
            beacon
        );

        return beacon;
    }
}
