
/*
Description: assign roles in resource group scope.
Usage:
  module roleAssignment '_roleAssignmentCrossResourceGroup.bicep' = {
    name: 'assign-role'
    scope: resourceGroup(resourceGroupName)
    params: {
      roleDefinitionId: roleDefinitionId
      principalId: principalId
    }
  }
*/

// https://docs.microsoft.com/en-us/azure/role-based-access-control/built-in-roles
param roleDefinitionId string
param principalId string

var name_roleAssignmentName = guid('${resourceGroup().id}${principalId}Deployment Script in AKS Node Resource Group')

// Get role resource id in the specified resource group
resource roleResourceDefinition 'Microsoft.Authorization/roleDefinitions@2018-01-01-preview' existing = {
  name: roleDefinitionId
}

// Assign role
resource roleAssignment 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = {
  name: name_roleAssignmentName
  properties: {
    description: 'Assign Resource Group role to User Assigned Managed Identity '
    principalId: principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: roleResourceDefinition.id
  }
}

output roleId string = roleResourceDefinition.id
