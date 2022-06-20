param utcValue string = utcNow()
param storageAccountName string = 'stg${toLower(utcValue)}'
param location string = 'eastus'

// https://docs.microsoft.com/en-us/azure/role-based-access-control/built-in-roles
var const_roleDefinitionIdOfContributor = 'b24988ac-6180-42a0-ab88-20f7382dd24c'
var const_azcliVersion = '2.15.0'
var const_sku = 'Standard_LRS'
var name_appGateway = 'appgw${uniqueString(utcValue)}'
var name_aksClusterName = 'wlsaks${uniqueString(utcValue)}'
var name_uami = 'wls-aks-deployment-script-user-defined-managed-itentity'
var name_uamiAKSIdentity = 'wls-aks-kubernetes-user-defined-managed-itentity'
var name_applicationGatewayUserDefinedManagedIdentity = 'wls-aks-application-gateway-user-defined-managed-itentity'
var name_aksContributorRoleAssignmentName = '${guid(concat(resourceGroup().id, name_uamiAKSIdentity, 'ForAKSCluster'))}'
var ref_gatewayId = resourceId('Microsoft.Network/applicationGateways', name_appGateway)

resource uami 'Microsoft.ManagedIdentity/userAssignedIdentities@2021-09-30-preview' = {
  name: name_uami
  location: location
}
resource uamiRoleAssignment 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = {
  name: guid(utcValue)
  properties: {
    description: 'Assign Resource Group Contributor role to User Assigned Managed Identity '
    principalId: reference(resourceId('Microsoft.ManagedIdentity/userAssignedIdentities', name_uami)).principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', const_roleDefinitionIdOfContributor)
  }
}
resource storageAccount 'Microsoft.Storage/storageAccounts@2021-02-01' = {
  name: storageAccountName
  location: location
  kind: 'StorageV2'
  sku: {
    name: const_sku
    tier: 'Standard'
  }
  properties: {
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Allow'
    }
    supportsHttpsTrafficOnly: true
    encryption: {
      services: {
        file: {
          keyType: 'Account'
          enabled: true
        }
      }
      keySource: 'Microsoft.Storage'
    }
    accessTier: 'Hot'
  }
  tags: {
    'managed-by-azure-weblogic': utcValue
  }
}

resource uamiAks 'Microsoft.ManagedIdentity/userAssignedIdentities@2021-09-30-preview' = {
  name: name_uamiAKSIdentity
  location: location
}

resource uamiRoleAssignment2 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = {
  name: name_aksContributorRoleAssignmentName
  properties: {
    description: 'Assign Resource Group Contributor role to User Assigned Managed Identity '
    principalId: reference(resourceId('Microsoft.ManagedIdentity/userAssignedIdentities', name_uamiAKSIdentity)).principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', const_roleDefinitionIdOfContributor)
  }
}

resource uamiGateway 'Microsoft.ManagedIdentity/userAssignedIdentities@2021-09-30-preview' = {
  name: name_applicationGatewayUserDefinedManagedIdentity
  location: location
}

module vnetForAppGateway 'modules/_vnetAppGateway.bicep' = {
  name: 'deploy-application-gateway-vnet'
  params: {
    location: location
  }
}

module appGateway 'modules/_appgateway.bicep' = {
  name: 'deploy-application-gateway'
  params: {
    location: location
    gatewayName: name_appGateway
    gatewaySubnetId: vnetForAppGateway.outputs.subIdForApplicationGateway
    uamiId: uamiGateway.id
    staticPrivateFrontentIP: ''
  }
  dependsOn:[
    vnetForAppGateway
  ]
}

module aks 'modules/_aks.bicep' = {
  name: 'deploy-aks'
  params: {
    clusterName: name_aksClusterName
    location: location
    uamiIdentifyId: uamiAks.id
    ingressApplicationGateway: {
      enabled: true
      config: {
        applicationGatewayId: ref_gatewayId
      }
      identity: {
        clientId: reference(resourceId('Microsoft.ManagedIdentity/userAssignedIdentities', name_applicationGatewayUserDefinedManagedIdentity)).clientId
        objectId: reference(resourceId('Microsoft.ManagedIdentity/userAssignedIdentities', name_applicationGatewayUserDefinedManagedIdentity)).principalId
        resourceId: uamiGateway.id
      }
    }
  }
  dependsOn:[
    uamiRoleAssignment2
    appGateway
  ]
}



resource deploymentScript 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  name: 'deployment-script'
  location: location
  kind: 'AzureCLI'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${uami.id}': {}
    }
  }
  properties: {
    azCliVersion: const_azcliVersion
    environmentVariables: [
      {
        name: 'NAME_STORAGE_ACCOUNT'
        value: storageAccountName
      }
      {
        name: 'NAME_RESOURCE_GROUP'
        value: resourceGroup().name
      }
    ]
    scriptContent: loadTextContent('./script.sh')
    cleanupPreference: 'OnExpiration'
    retentionInterval: 'P1D'
    forceUpdateTag: utcValue
  }
  dependsOn:[
    aks
  ]
}
