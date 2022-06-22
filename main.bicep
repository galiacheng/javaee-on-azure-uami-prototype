param utcValue string = utcNow()
param storageAccountName string = 'stg${toLower(utcValue)}'
param location string = 'eastus'

// https://docs.microsoft.com/en-us/azure/role-based-access-control/built-in-roles
var const_azcliVersion = '2.15.0'
var const_appGatewayDns = '${format('{0}.{1}.{2}', name_domainLabelforApplicationGateway, location, 'cloudapp.azure.com')}'
var const_roleDefinitionIdOfContributor = 'b24988ac-6180-42a0-ab88-20f7382dd24c'
var const_sku = 'Standard_LRS'
var name_aksClusterName = 'wlsaks${uniqueString(utcValue)}'
var name_aksContributorRoleAssignmentName = '${guid(concat(resourceGroup().id, name_aksUserDefinedManagedIdentity, 'ForAKSCluster'))}'
var name_aksUserDefinedManagedIdentity = 'wls-aks-kubernetes-user-defined-managed-itentity'
var name_applicationGatewayName = 'appgw${uniqueString(utcValue)}'
var name_applicationGatewayUserDefinedManagedIdentity = 'wls-aks-application-gateway-user-defined-managed-itentity'
var name_appGwContributorRoleAssignmentName = '${guid(concat(resourceGroup().id, utcValue, 'ForApplicationGateway'))}'
var name_certForApplicationGatwayFrontend = 'appGatewaySslCert'
var name_deploymentScriptUserDefinedManagedIdentity = 'wls-aks-deployment-script-user-defined-managed-itentity'
var name_deploymentScriptContributorRoleAssignmentName = '${guid(concat(resourceGroup().id, name_deploymentScriptUserDefinedManagedIdentity, 'ForAKSCluster'))}'
var name_domainLabelforApplicationGateway = '${take(concat('wlsonaks', take(utcValue, 6), '-', toLower(name_rgNameWithoutSpecialCharacter)), 63)}'
var name_keyvault = 'kv${uniqueString(utcValue)}'
var name_keyvaultSecretForAppGatewayFrontend = 'myApplicationGatewayFrontendCert'
var name_rgNameWithoutSpecialCharacter = replace(replace(replace(replace(resourceGroup().name, '.', ''), '(', ''), ')', ''), '_', '') // remove . () _ from resource group name
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

resource gatewayUAMIRoleAssignment 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = {
  name: name_appGwContributorRoleAssignmentName
  properties: {
    description: 'Assign Resource Group Contributor role to User Assigned Managed Identity '
    principalId: reference(resourceId('Microsoft.ManagedIdentity/userAssignedIdentities', name_applicationGatewayUserDefinedManagedIdentity)).principalId
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

resource keyvault 'Microsoft.KeyVault/vaults@2021-10-01' = {
  name: name_keyvault
  location: location
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: subscription().tenantId
    accessPolicies: [
      {
        // Must specify API version of identity.
        objectId: reference(uamiForApplicationGateway.id, '2018-11-30').principalId
        tenantId: reference(uamiForApplicationGateway.id, '2018-11-30').tenantId
        permissions: {
          secrets: [
            'get'
            'list'
          ]
          certificates: [
            'get'
          ]
        }
      }
      {
        // Must specify API version of identity.
        objectId: reference(uamiForDeploymentScript.id, '2018-11-30').principalId
        tenantId: reference(uamiForDeploymentScript.id, '2018-11-30').tenantId
        permissions: {
          certificates: [
            'get'
            'list'
            'update'
            'create'
          ]
        }
      }
    ]
    enabledForDeployment: false
    enabledForDiskEncryption: false
    enabledForTemplateDeployment: true
    enableSoftDelete: true
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

module certificates 'modules/_certForAppGateway.bicep' = {
  name: 'deploy-application-gateway-frontend-certificate'
  params:{
    keyVaultName: name_keyvault
    subjectName: format('CN={0}', const_appGatewayDns)
    identity: {
      type: 'UserAssigned'
      userAssignedIdentities: {
        '${uamiForDeploymentScript.id}': {}
      }
    }
    location: location
    secretName: name_keyvaultSecretForAppGatewayFrontend
  }
  dependsOn:[
    keyvault
  ]
}

module appGateway 'modules/_appgateway.bicep' = {
  name: 'deploy-application-gateway'
  params: {
    dnsNameforApplicationGateway: name_domainLabelforApplicationGateway
    location: location
    gatewayName: name_applicationGatewayName
    gatewaySubnetId: vnet.outputs.subIdForApplicationGateway
    gatwaySslCertName: name_certForApplicationGatwayFrontend
    keyVaultSecretId: concat(reference(name_keyvault).vaultUri, 'secrets/${name_keyvaultSecretForAppGatewayFrontend}')
    uamiId: uamiForApplicationGateway.id
    staticPrivateFrontentIP: ''
  }
  dependsOn: [
    vnet
    certificates
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
      {
        name: 'NAME_APPGATEWAY_FRONTEND_CERT'
        value: name_certForApplicationGatwayFrontend
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
