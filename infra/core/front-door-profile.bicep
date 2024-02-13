@description('The name of the Front Door endpoint to create. This must be globally unique.')
param frontDoorProfileName string = 'afd-${uniqueString(resourceGroup().id)}'

@description('Id of the log analytics workspace.')
param logAnalyticsWorkspaceId string

param logRetentionInDays int = 30

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
}

resource logAnalyticsWorkspaceDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: frontDoorProfile
  name: 'diagnosticSettings'
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      {
        category: 'FrontDoorWebApplicationFirewallLog'
        enabled: true
        retentionPolicy: {
          days: logRetentionInDays
          enabled: true
        }
      }
    ]
  }
}

output id string = frontDoorProfile.id
output name string = frontDoorProfile.name
output frontDoorId string = frontDoorProfile.properties.frontDoorId
