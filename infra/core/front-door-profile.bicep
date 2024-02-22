@description('The name of the Front Door endpoint to create. This must be globally unique.')
param frontDoorProfileName string = 'afd-${uniqueString(resourceGroup().id)}'

param dnsZoneName string

@description('Id of the log analytics workspace.')
param logAnalyticsWorkspaceId string

@description('Tags for all resources.')
param tags object = {}

@description('The name of the SKU to use when creating the Front Door profile.')
@allowed([
  'Standard_AzureFrontDoor'
  'Premium_AzureFrontDoor'
])
param frontDoorSkuName string = 'Standard_AzureFrontDoor'

resource frontDoorProfile 'Microsoft.Cdn/profiles@2023-07-01-preview' = {
  name: frontDoorProfileName
  location: 'global'
  tags: tags
  sku: {
    name: frontDoorSkuName
  }
  identity: {
    type: 'SystemAssigned'
  }
}

resource zone 'Microsoft.Network/dnsZones@2018-05-01' = {
  name: dnsZoneName
  location: 'global'
}

resource frontDoorProfileDiagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (logAnalyticsWorkspaceId != '') {
  scope: frontDoorProfile
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

output id string = frontDoorProfile.id
output name string = frontDoorProfile.name
output frontDoorId string = frontDoorProfile.properties.frontDoorId
output frontDoorPrincipalId string = frontDoorProfile.identity.principalId
