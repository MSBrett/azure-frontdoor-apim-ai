@description('The name of the AKS cluster')
param clusterName string
param clusterResourceGroupName string
param yamlFile string

@description('The location of the key vault and the identity')
param location string

param identityResourceId string

param identityPrincipalId string

var rbacRoles = [
  '8e3af657-a8ff-443c-a75c-2fe8c4bcb635' // Owner
]

resource aks 'Microsoft.ContainerService/managedClusters@2024-01-01' existing = {
  name: clusterName
}

// Assign access to the identity
resource identityRoleAssignments 'Microsoft.Authorization/roleAssignments@2022-04-01' = [for role in rbacRoles: {
  name: guid(aks.id, role, identityResourceId)
  scope: resourceGroup()
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', role)
    principalId: identityPrincipalId
    principalType: 'ServicePrincipal'
  }
}]

resource deployContainer 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  name: 'deployContainer'
  kind: 'AzurePowerShell'
  // chinaeast2 is the only region in China that supports deployment scripts
  location: startsWith(location, 'china') ? 'chinaeast2' : location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${identityResourceId}': {}
    }
  }
  dependsOn: [
    identityRoleAssignments
  ]
  properties: {
    azPowerShellVersion: '8.0'
    retentionInterval: 'PT1H'
    environmentVariables: [
      {
        name: 'clusterResourceGroupName'
        value: clusterResourceGroupName
      }
      {
        name: 'clusterName'
        value: clusterName
      }
      {
        name: 'yamlFile'
        value: yamlFile
      }
    ]
    scriptContent: loadTextContent('./scripts/deploy-container.ps1')
  }
}

