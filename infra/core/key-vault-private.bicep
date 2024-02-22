@description('Name of the resource.')
param name string
@description('Location to deploy the resource. Defaults to the location of the resource group.')
param location string = resourceGroup().location
@description('Tags for the resource.')
param tags object = {}

param privateEndpointSubnetId string
param virtualNetworkId string
param publicIpAddressToAllow string

type roleAssignmentInfo = {
    roleDefinitionId: string
    principalId: string
}

@description('Key Vault SKU name. Defaults to standard.')
@allowed([
    'standard'
    'premium'
])
param skuName string = 'standard'
@description('Whether soft deletion is enabled. Defaults to true.')
param enableSoftDelete bool = true
@description('Role assignments to create for the Key Vault.')
param roleAssignments roleAssignmentInfo[] = []
param logAnalyticsWorkspaceId string = ''
var privateEndpointName = '${name}-ep'
var privateDnsZoneName = 'privatelink.vaultcore.azure.net'
var pvtEndpointDnsGroupName = '${privateEndpointName}/keyvault-endpoint-zone'

resource keyVault 'Microsoft.KeyVault/vaults@2022-07-01' = {
    name: name
    location: location
    tags: tags
    properties: {
        sku: {
            family: 'A'
            name: skuName
        }
        tenantId: subscription().tenantId
        networkAcls: {
            defaultAction: 'allow' // so APIM can access it
            bypass: 'AzureServices'
            ipRules: [
              {
                value: '${publicIpAddressToAllow}/32'
              }
            ]
        }
        enableSoftDelete: enableSoftDelete
        enabledForTemplateDeployment: true
        enableRbacAuthorization: true
    }
}

resource assignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = [for roleAssignment in roleAssignments: {
    name: guid(keyVault.id, roleAssignment.principalId, roleAssignment.roleDefinitionId)
    scope: keyVault // resourceGroup()
    properties: {
      roleDefinitionId: roleAssignment.roleDefinitionId
      principalId: roleAssignment.principalId
      principalType: 'ServicePrincipal'
    }
}]

resource privateEndpoint 'Microsoft.Network/privateEndpoints@2021-05-01' =  {
  name: privateEndpointName
  location: location
  properties: {
    subnet: {
      id: privateEndpointSubnetId
    }
    privateLinkServiceConnections: [
      {
        name: privateEndpointName
        properties: {
          privateLinkServiceId: keyVault.id
          groupIds: [
            'vault'
          ]
        }
      }
    ]
  }
}

resource privateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: privateDnsZoneName
  location: 'global'
  properties: {}
}

resource privateDnsZoneLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' =  {
  parent: privateDnsZone
  name: '${privateDnsZoneName}-link'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: virtualNetworkId
    }
  }
}

resource pvtEndpointDnsGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2021-05-01' = {
  name: pvtEndpointDnsGroupName
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'config1'
        properties: {
          privateDnsZoneId: privateDnsZone.id
        }
      }
    ]
  }
  dependsOn: [
    privateEndpoint
  ]
}

resource keyVaultDiagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (logAnalyticsWorkspaceId != '') {
  scope: keyVault
  name: 'sccDiagnosticSettings'
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      {
        categoryGroup: 'allLogs'
        enabled: true
      }
    ]
  }
}

@description('ID for the deployed Key Vault resource.')
output id string = keyVault.id
@description('Name for the deployed Key Vault resource.')
output name string = keyVault.name
@description('URI for the deployed Key Vault resource.')
output uri string = keyVault.properties.vaultUri
