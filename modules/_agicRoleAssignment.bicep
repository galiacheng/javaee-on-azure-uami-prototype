param aksClusterName string = 'haiche-aks-test2'
param aksClusterRGName string = 'haiche-existing-aks-2'
param roleDefinitionId string = 'b24988ac-6180-42a0-ab88-20f7382dd24c'
param utcValue string = utcNow()

var name_appGwContributorRoleAssignmentName = guid('${resourceGroup().id}${utcValue}ForApplicationGateway')

resource aksCluster 'Microsoft.ContainerService/managedClusters@2021-02-01' existing = {
  name: aksClusterName
  scope: resourceGroup(aksClusterRGName)
}

resource agicUamiRoleAssignment 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = {
  name: name_appGwContributorRoleAssignmentName
  properties: {
    description: 'Assign Resource Group Contributor role to User Assigned Managed Identity '
    principalId: reference(aksCluster.id, '2020-12-01', 'Full').properties.addonProfiles.ingressApplicationGateway.identity.objectId
    principalType: 'ServicePrincipal'
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', roleDefinitionId)
  }
  dependsOn: [
    aksCluster
  ]
}
