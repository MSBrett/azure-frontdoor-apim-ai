targetScope = 'subscription'

@minLength(1)
@maxLength(64)
@description('Name of the log analytics workspace to create.')
param logAnalyticsWorkspaceName string

@minLength(1)
@description('Primary location for all resources.')
param location string

@description('Name of the resource group. If empty, a unique name will be generated.')
param logAnalyticsResourceGroupName string = 'Observability'

@description('Name of the resource group. If empty, a unique name will be generated.')
param azureFrontDoorResourceGroupName string = 'GlobalNetwork'

param publicIpAddressToAllow string

param dnsZoneName string

@description('Tags for all resources.')
param tags object = {}

var abbrs = loadJsonContent('./abbreviations.json')
var roles = loadJsonContent('./roles.json')
var resourceToken = toLower(uniqueString(subscription().id, logAnalyticsResourceGroupName, location))
var workspaceName = !empty(logAnalyticsWorkspaceName) ? logAnalyticsWorkspaceName : '${abbrs.logAnalyticsWorkspace}${resourceToken}'

resource logAnalyticsResourceGroup 'Microsoft.Resources/resourceGroups@2022-09-01' = {
  name: logAnalyticsResourceGroupName
  location: location
  tags: union(tags, {})
}

resource azureFrontDoorResourceGroup 'Microsoft.Resources/resourceGroups@2022-09-01' = {
  name: azureFrontDoorResourceGroupName
  location: location
  tags: union(tags, {})
}

module logAnalyticsWorkspace 'core/log-analytics.bicep' = {
  name: workspaceName
  scope: logAnalyticsResourceGroup
  params: {
    name: workspaceName
    location: location
    tags: tags
    retentionInDays: 30
    sku: 'PerGB2018'
  }
}

module frontDoorProfile './core/front-door-profile.bicep' = {
  name: '${abbrs.frontDoorProfile}${resourceToken}'
  scope: azureFrontDoorResourceGroup
  params: {
    frontDoorProfileName: '${abbrs.frontDoorProfile}${resourceToken}'
    tags: union(tags, {})
    frontDoorSkuName: 'Premium_AzureFrontDoor'
    logAnalyticsWorkspaceId: logAnalyticsWorkspace.outputs.id
    dnsZoneName: dnsZoneName
  }
}

output logAnalyticsWorkspaceId string = logAnalyticsWorkspace.outputs.id
output logAnalyticsWorkspaceName string = logAnalyticsWorkspace.outputs.name
output logAnalyticsWorkspaceSubscriptionId string = subscription().id

output frontDoorProfileName string = frontDoorProfile.outputs.name
output frontDoorProfileId string = frontDoorProfile.outputs.id
output frontDoorId string = frontDoorProfile.outputs.frontDoorId
