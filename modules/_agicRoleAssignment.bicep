param aksClusterName string 
param aksClusterRGName string
param roleDefinitionId string
param utcValue string = utcNow()

var const_APIVersion = '2020-12-01'
var name_appGwContributorRoleAssignmentName = guid('${resourceGroup().id}${utcValue}ForApplicationGateway')

resource aksCluster 'Microsoft.ContainerService/managedClusters@2021-02-01' existing = {
  name: aksClusterName
  scope: resourceGroup(aksClusterRGName)
}

resource agicUamiRoleAssignment 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = {
  name: name_appGwContributorRoleAssignmentName
  properties: {
    description: 'Assign Resource Group Contributor role to User Assigned Managed Identity '
    principalId: reference(aksCluster.id, const_APIVersion , 'Full').properties.addonProfiles.ingressApplicationGateway.identity.objectId
    principalType: 'ServicePrincipal'
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', roleDefinitionId)
  }
  dependsOn: [
    aksCluster
  ]
}
