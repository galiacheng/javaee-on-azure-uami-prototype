@maxLength(12)
@minLength(1)
@description('The name for this node pool. Node pool must contain only lowercase letters and numbers. For Linux node pools the name cannot be longer than 12 characters.')
param aksAgentPoolName string = 'agentpool'
@maxValue(10000)
@minValue(1)
@description('The number of nodes that should be created along with the cluster. You will be able to resize the cluster later.')
param aksAgentPoolNodeCount int = 3
@description('The size of the virtual machines that will form the nodes in the cluster. This cannot be changed after creating the cluster')
param aksAgentPoolVMSize string = 'Standard_DS2_v2'
@description('Prefix for cluster name. Only The name can contain only letters, numbers, underscores and hyphens. The name must start with letter or number.')
param aksVersion string = '1.23.5'
param clusterName string
param ingressApplicationGateway object
@description('In addition to the CPU and memory metrics included in AKS by default, you can enable Container Insights for more comprehensive data on the overall performance and health of your cluster. Billing is based on data ingestion and retention settings.')
param location string
param vnetSubnetID string

var const_aksAgentPoolOSDiskSizeGB = 128
var const_aksAgentPoolMaxPods = 110
var const_aksAvailabilityZones = [
  '1'
  '2'
  '3'
]

resource aksCluster 'Microsoft.ContainerService/managedClusters@2021-02-01' = {
  name: clusterName
  location: location
  properties: {
    kubernetesVersion: aksVersion
    dnsPrefix: '${clusterName}-dns'
    agentPoolProfiles: [
      {
        name: aksAgentPoolName
        count: aksAgentPoolNodeCount
        vmSize: aksAgentPoolVMSize
        vnetSubnetID: vnetSubnetID
        osDiskSizeGB: const_aksAgentPoolOSDiskSizeGB
        osDiskType: 'Managed'
        kubeletDiskType: 'OS'
        maxPods: const_aksAgentPoolMaxPods
        type: 'VirtualMachineScaleSets'
        availabilityZones: const_aksAvailabilityZones
        mode: 'System'
        osType: 'Linux'
      }
    ]
    addonProfiles: {
      KubeDashboard: {
        enabled: false
      }
      azurepolicy: {
        enabled: false
      }
      httpApplicationRouting: {
        enabled: false
      }
      omsAgent: {
        enabled: false
      }
      ingressApplicationGateway: ingressApplicationGateway
    }
    enableRBAC: true
    networkProfile: {
      networkPlugin: 'kubenet'
      loadBalancerSku: 'standard'
    }
  }
  identity: {
    type: 'SystemAssigned'
  }
}
