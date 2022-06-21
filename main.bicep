param utcValue string = utcNow()
param storageAccountName string = 'stg${toLower(utcValue)}'
param location string = 'eastus'

// https://docs.microsoft.com/en-us/azure/role-based-access-control/built-in-roles
var const_azcliVersion = '2.15.0'
var const_roleDefinitionIdOfContributor = 'b24988ac-6180-42a0-ab88-20f7382dd24c'
var const_sku = 'Standard_LRS'
var name_aksClusterName = 'wlsaks${uniqueString(utcValue)}'
var name_aksContributorRoleAssignmentName = '${guid(concat(resourceGroup().id, name_aksUserDefinedManagedIdentity, 'ForAKSCluster'))}'
var name_aksUserDefinedManagedIdentity = 'wls-aks-kubernetes-user-defined-managed-itentity'
var name_applicationGatewayName = 'appgw${uniqueString(utcValue)}'
var name_applicationGatewayUserDefinedManagedIdentity = 'wls-aks-application-gateway-user-defined-managed-itentity'
var name_deploymentScriptUserDefinedManagedIdentity = 'wls-aks-deployment-script-user-defined-managed-itentity'
var name_deploymentScriptContributorRoleAssignmentName = '${guid(concat(resourceGroup().id, name_deploymentScriptUserDefinedManagedIdentity, 'ForAKSCluster'))}'

var ref_gatewayId = resourceId('Microsoft.Network/applicationGateways', name_applicationGatewayName)

// UAMI for deployment script
resource uamiForDeploymentScript 'Microsoft.ManagedIdentity/userAssignedIdentities@2021-09-30-preview' = {
  name: name_deploymentScriptUserDefinedManagedIdentity
  location: location
}
resource deploymentScriptUAMICotibutorRoleAssignment 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = {
  name: name_deploymentScriptContributorRoleAssignmentName
  properties: {
    description: 'Assign Resource Group Contributor role to User Assigned Managed Identity '
    principalId: reference(resourceId('Microsoft.ManagedIdentity/userAssignedIdentities', name_deploymentScriptUserDefinedManagedIdentity)).principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', const_roleDefinitionIdOfContributor)
  }
}

// UAMI for AKS
resource uamiForAks 'Microsoft.ManagedIdentity/userAssignedIdentities@2021-09-30-preview' = {
  name: name_aksUserDefinedManagedIdentity
  location: location
}

resource aksUAMICotibutorRoleAssignment 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = {
  name: name_aksContributorRoleAssignmentName
  properties: {
    description: 'Assign Resource Group Contributor role to User Assigned Managed Identity '
    principalId: reference(resourceId('Microsoft.ManagedIdentity/userAssignedIdentities', name_aksUserDefinedManagedIdentity)).principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', const_roleDefinitionIdOfContributor)
  }
}

// UAMI for Application Gateway
resource uamiForApplicationGateway 'Microsoft.ManagedIdentity/userAssignedIdentities@2021-09-30-preview' = {
  name: name_applicationGatewayUserDefinedManagedIdentity
  location: location
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

module vnet 'modules/_vnet.bicep' = {
  name: 'deploy-application-gateway-vnet'
  params: {
    location: location
  }
}

module appGateway 'modules/_appgateway.bicep' = {
  name: 'deploy-application-gateway'
  params: {
    location: location
    gatewayName: name_applicationGatewayName
    gatewaySubnetId: vnet.outputs.subIdForApplicationGateway
    uamiId: uamiForApplicationGateway.id
    staticPrivateFrontentIP: ''
  }
  dependsOn: [
    vnet
  ]
}

module aks 'modules/_aks.bicep' = {
  name: 'deploy-aks'
  params: {
    clusterName: name_aksClusterName
    location: location
    uamiIdentifyId: uamiForAks.id
    ingressApplicationGateway: {
      enabled: true
      config: {
        applicationGatewayId: ref_gatewayId
      }
      identity: {
        clientId: reference(resourceId('Microsoft.ManagedIdentity/userAssignedIdentities', name_applicationGatewayUserDefinedManagedIdentity)).clientId
        objectId: reference(resourceId('Microsoft.ManagedIdentity/userAssignedIdentities', name_applicationGatewayUserDefinedManagedIdentity)).principalId
        resourceId: uamiForApplicationGateway.id
      }
    }
    vnetSubnetID: vnet.outputs.subIdForAKS
  }
  dependsOn: [
    aksUAMICotibutorRoleAssignment
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
      '${uamiForDeploymentScript.id}': {}
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
      {
        name: 'NAME_AKS_CLUSTER'
        value: name_aksClusterName
      }
    ]
    scriptContent: loadTextContent('./script.sh')
    cleanupPreference: 'OnExpiration'
    retentionInterval: 'P1D'
    forceUpdateTag: utcValue
  }
  dependsOn: [
    aks
  ]
}
