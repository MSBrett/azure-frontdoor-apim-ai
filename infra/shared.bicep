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

resource logAnalyticsResourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: logAnalyticsResourceGroupName
  location: location
  tags: union(tags, {})
}

resource azureFrontDoorResourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' = {
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
    frontDoorSkuName: 'Standard_AzureFrontDoor'
    logAnalyticsWorkspaceId: logAnalyticsWorkspace.outputs.id
    dnsZoneName: dnsZoneName
  }
}

resource keyVaultAdministrator 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  scope: azureFrontDoorResourceGroup
  name: roles.keyVaultAdministrator
}

resource keyVaultSecretsOfficer 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  scope: azureFrontDoorResourceGroup
  name: roles.keyVaultSecretsOfficer
}

resource keyVaultCertificatesOfficer 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  scope: azureFrontDoorResourceGroup
  name: roles.keyVaultCertificatesOfficer
}

resource keyVaultSecretsUser 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  scope: azureFrontDoorResourceGroup
  name: roles.keyVaultSecretsUser
}

module keyVault './core/key-vault-shared.bicep' = {
  name: '${abbrs.keyVault}${resourceToken}'
  scope: azureFrontDoorResourceGroup
  params: {
    name: '${abbrs.keyVault}${resourceToken}'
    location: location
    tags: union(tags, {})
    publicIpAddressToAllow: publicIpAddressToAllow
    roleAssignments: [
      {
        principalId: frontDoorProfile.outputs.frontDoorPrincipalId
        roleDefinitionId: keyVaultAdministrator.id
      }
      {
        principalId: frontDoorProfile.outputs.frontDoorPrincipalId
        roleDefinitionId: keyVaultSecretsOfficer.id
      }
      {
        principalId: frontDoorProfile.outputs.frontDoorPrincipalId
        roleDefinitionId: keyVaultSecretsUser.id
      }
      {
        principalId: frontDoorProfile.outputs.frontDoorPrincipalId
        roleDefinitionId: keyVaultCertificatesOfficer.id
      }
    ]
  }
}

output logAnalyticsWorkspaceId string = logAnalyticsWorkspace.outputs.id
output logAnalyticsWorkspaceName string = logAnalyticsWorkspace.outputs.name
output logAnalyticsWorkspaceSubscriptionId string = subscription().id

output frontDoorProfileName string = frontDoorProfile.outputs.name
output frontDoorProfileId string = frontDoorProfile.outputs.id
output frontDoorId string = frontDoorProfile.outputs.frontDoorId
