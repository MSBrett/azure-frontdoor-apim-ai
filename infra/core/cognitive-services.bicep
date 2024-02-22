@description('Name of the resource.')
param name string
@description('Location to deploy the resource. Defaults to the location of the resource group.')
param location string = resourceGroup().location
@description('Tags for the resource.')
param tags object = {}

type keyVaultSecretInfo = {
  name: string
  property: 'PrimaryKey'
}

type keyVaultSecretsInfo = {
  name: string
  secrets: keyVaultSecretInfo[]
}

param privateEndpointSubnetId string
param virtualNetworkId string

@description('Cognitive Services SKU. Defaults to S0.')
param sku object = {
  name: 'S0'
}
@description('Cognitive Services Kind. Defaults to OpenAI.')
@allowed([
  'Bing.Speech'
  'SpeechTranslation'
  'TextTranslation'
  'Bing.Search.v7'
  'Bing.Autosuggest.v7'
  'Bing.CustomSearch'
  'Bing.SpellCheck.v7'
  'Bing.EntitySearch'
  'Face'
  'ComputerVision'
  'ContentModerator'
  'TextAnalytics'
  'LUIS'
  'SpeakerRecognition'
  'CustomSpeech'
  'CustomVision.Training'
  'CustomVision.Prediction'
  'OpenAI'
])
param kind string = 'OpenAI'
@description('List of deployments for Cognitive Services.')
param deployments array = []
@description('Whether to enable public network access. Defaults to Enabled.')
@allowed([
  'Enabled'
  'Disabled'
])
param publicNetworkAccess string = 'Enabled'
@description('Properties to store in a Key Vault.')
param keyVaultSecrets keyVaultSecretsInfo?
param logAnalyticsWorkspaceId string = ''
var privateEndpointName = '${name}-ep}'
var privateDnsZoneName = 'privatelink.openai.azure.com'
var pvtEndpointDnsGroupName = '${privateEndpointName}/openai-endpoint-zone'

resource cognitiveServices 'Microsoft.CognitiveServices/accounts@2023-05-01' = {
  name: name
  location: location
  tags: tags
  kind: kind
  properties: {
    customSubDomainName: toLower(name)
    publicNetworkAccess: publicNetworkAccess
    networkAcls: {
      defaultAction: 'Allow'
      ipRules: []
      virtualNetworkRules: []
    }
  }
  sku: sku
}

@batchSize(1)
resource deployment 'Microsoft.CognitiveServices/accounts/deployments@2023-05-01' = [for deployment in deployments: {
  parent: cognitiveServices
  name: deployment.name
  properties: {
    model: contains(deployment, 'model') ? deployment.model : null
    raiPolicyName: contains(deployment, 'raiPolicyName') ? deployment.raiPolicyName : null
  }
  sku: contains(deployment, 'sku') ? deployment.sku : {
    name: 'Standard'
    capacity: 100
  }
}]

module keyVaultSecret './key-vault-secret.bicep' = [for secret in keyVaultSecrets.?secrets!: {
  name: '${secret.name}-secret'
  params: {
    keyVaultName: keyVaultSecrets.?name!
    name: secret.name
    value: secret.property == 'PrimaryKey' ? cognitiveServices.listKeys().key1 : ''
  }
}]

resource privateEndpoint 'Microsoft.Network/privateEndpoints@2023-04-01' = {
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
          privateLinkServiceId: cognitiveServices.id
          groupIds: [
            'account'
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

resource privateDnsZoneLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
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

resource pvtEndpointDnsGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-04-01' = {
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

resource cognitiveServicesDiagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (logAnalyticsWorkspaceId != '') {
  scope: cognitiveServices
  name: 'diagnosticSettings'
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

@description('ID for the deployed Cognitive Services resource.')
output id string = cognitiveServices.id
@description('Name for the deployed Cognitive Services resource.')
output name string = cognitiveServices.name
@description('Endpoint for the deployed Cognitive Services resource.')
output endpoint string = cognitiveServices.properties.endpoint
@description('Host for the deployed Cognitive Services resource.')
output host string = split(cognitiveServices.properties.endpoint, '/')[2]

output privateDnsZoneName string = privateDnsZoneName
