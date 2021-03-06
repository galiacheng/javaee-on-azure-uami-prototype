// Copyright (c) 2021, Oracle Corporation and/or its affiliates.
// Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.

param createAKSCluster bool
param location string
param vnetForApplicationGateway object = {
  name: 'wlsaks-app-gateway-vnet'
  resourceGroup: resourceGroup().name
  addressPrefixes: [
    '10.3.0.0/16'
  ]
  addressPrefix: '10.3.0.0/16'
  newOrExisting: 'new'
  subnets: {
    gatewaySubnet: {
      name: 'wlsaks-gateway-subnet'
      addressPrefix: '10.3.0.0/24'
      startAddress: '10.3.0.4'
    }
    aksSubnet: {
      name: 'wlsaks-subnet'
      addressPrefix: '10.3.1.0/24'
      startAddress: '10.3.1.4'
    }
  }
}
param utcValue string = utcNow()

var const_aksSubnetAddressPrefixes = vnetForApplicationGateway.subnets.aksSubnet.addressPrefix
var const_subnetAddressPrefixes = vnetForApplicationGateway.subnets.gatewaySubnet.addressPrefix
var const_vnetAddressPrefixes = vnetForApplicationGateway.addressPrefixes
var const_newVnet = (vnetForApplicationGateway.newOrExisting == 'new') ? true : false
var name_nsg = 'wlsaks-nsg-${uniqueString(utcValue)}'
var name_subnet = vnetForApplicationGateway.subnets.gatewaySubnet.name
var name_aksSubnet = vnetForApplicationGateway.subnets.aksSubnet.name
var name_vnet = vnetForApplicationGateway.name
var obj_onesubnet = [
  {
    name: name_subnet
    properties: {
      addressPrefix: const_subnetAddressPrefixes
      networkSecurityGroup: {
        id: nsg.id
      }
    }
  }
]
var obj_twosubnet = [
  {
    name: name_subnet
    properties: {
      addressPrefix: const_subnetAddressPrefixes
      networkSecurityGroup: {
        id: nsg.id
      }
    }
  }
  {
    name: name_aksSubnet
    properties: {
      addressPrefix: const_aksSubnetAddressPrefixes
      networkSecurityGroup: {
        id: nsg.id
      }
    }
  }
]

// Create new network security group.
resource nsg 'Microsoft.Network/networkSecurityGroups@2021-08-01' = if (const_newVnet) {
  name: name_nsg
  location: location
  properties: {
    securityRules: [
      {
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '65200-65535'
          sourceAddressPrefix: 'GatewayManager'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 500
          direction: 'Inbound'
        }
        name: 'ALLOW_APPGW'
      }
      {
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          sourceAddressPrefix: 'Internet'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 510
          direction: 'Inbound'
          destinationPortRanges: [
            '80'
            '443'
          ]
        }
        name: 'ALLOW_HTTP_ACCESS'
      }
    ]
  }
}

// Create new VNET and subnet.
resource newVnet 'Microsoft.Network/virtualNetworks@2021-08-01' = if (const_newVnet) {
  name: name_vnet
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: const_vnetAddressPrefixes
    }
    subnets: createAKSCluster ? obj_twosubnet : obj_onesubnet
  }
}

output subIdForApplicationGateway string = resourceId('Microsoft.Network/virtualNetworks/subnets', name_vnet, name_subnet)
output subIdForAKS string = createAKSCluster ? resourceId('Microsoft.Network/virtualNetworks/subnets', name_vnet, name_aksSubnet) : ''
