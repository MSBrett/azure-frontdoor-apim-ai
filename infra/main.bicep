targetScope = 'subscription'

@minLength(1)
@maxLength(64)
@description('Name of the workload which is used to generate a short unique hash used in all resources.')
param workloadName string


@minLength(1)
@maxLength(64)
@description('The custom DNS name to use.')
param dnsName string

@minLength(1)
@description('Primary location for all resources.')
param location string

@description('Name of the resource group. If empty, a unique name will be generated.')
param resourceGroupName string = ''

@description('Tags for all resources.')
param tags object = {}

param virtualNetworkAddressPrefix string = '10.2.0.0/23'

type openAIInstanceInfo = {
  name: string?
  location: string
  suffix: string
}

@description('Name of the Managed Identity. If empty, a unique name will be generated.')
param managedIdentityName string = ''
@description('Name of the Key Vault. If empty, a unique name will be generated.')
param keyVaultName string = ''
@description('Name of the Key Vault certificate. If empty, a unique name will be generated.')
param certificateName string = ''
@description('OpenAI instances to deploy. Defaults to 2 across different regions.')
param openAIInstances openAIInstanceInfo[] = [
  {
    name: ''
    location: location
    suffix: location
  }
]
@description('Name of the API Management service. If empty, a unique name will be generated.')
param apiManagementName string = ''
@description('Email address for the API Management service publisher.')
param apiManagementPublisherEmail string
@description('Name of the API Management service publisher.')
param apiManagementPublisherName string

@description('Contact DL for security center alerts')
param securityCenterContactEmail string

@description('Optional. Deploy Azure Security Center. Default: false.')
param deploySecurityCenter bool = false

@description('Log Analytics Workspace Id')
param logAnalyticsWorkspaceId string 

@description('Log Analytics Workspace Resource Group')
param logAnalyticsWorkspaceRg string

@description('Log Analytics Workspace Name')
param logAnalyticsWorkspaceName string

@description('Log Analytics Workspace Location')
param logAnalyticsWorkspaceLocation string

var abbrs = loadJsonContent('./abbreviations.json')
var roles = loadJsonContent('./roles.json')
var resourceToken = toLower(uniqueString(subscription().id, workloadName, location))

resource resourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: !empty(resourceGroupName) ? resourceGroupName : '${abbrs.resourceGroup}${workloadName}'
  location: location
  tags: union(tags, {})
}

/*
module security_center 'core/security-center.bicep' = if (deploySecurityCenter) {
  name: 'securityCenter'
  scope: subscription()
  params: {
    securityCenterContactEmail: securityCenterContactEmail
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId
    logAnalyticsWorkspaceLocation: logAnalyticsWorkspaceLocation
    logAnalyticsWorkspaceName: logAnalyticsWorkspaceName
    logAnalyticsWorkspaceRg: logAnalyticsWorkspaceRg
  }
}
*/

module virtualNetwork 'core/virtual-network.bicep' = {
  name: '${abbrs.virtualNetwork}${resourceToken}'
  scope: resourceGroup
  params: {
    location: location
    tags: union(tags, {})
    virtualNetworkAddressPrefix: virtualNetworkAddressPrefix
    bastionHostName: '${abbrs.virtualNetwork}${resourceToken}'
    ddosPlanName: '${abbrs.ddosPlan}${resourceToken}'
    publicIpName: '${abbrs.publicIPAddress}${resourceToken}'
    virtualNetworkName: '${abbrs.virtualNetwork}${resourceToken}'
  }
}

module managedIdentity './core/managed-identity.bicep' = {
  name: !empty(managedIdentityName) ? managedIdentityName : '${abbrs.managedIdentity}${resourceToken}'
  scope: resourceGroup
  params: {
    name: !empty(managedIdentityName) ? managedIdentityName : '${abbrs.managedIdentity}${resourceToken}'
    location: location
    tags: union(tags, {})
  }
}

resource keyVaultAdministrator 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  scope: resourceGroup
  name: roles.keyVaultAdministrator
}

resource keyVaultSecretsOfficer 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  scope: resourceGroup
  name: roles.keyVaultSecretsOfficer
}

resource keyVaultCertificatesOfficer 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  scope: resourceGroup
  name: roles.keyVaultCertificatesOfficer
}

resource keyVaultSecretsUser 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  scope: resourceGroup
  name: roles.keyVaultSecretsUser
}

resource owner 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  scope: resourceGroup
  name: roles.owner
}

module keyVault './core/key-vault.bicep' = {
  name: !empty(keyVaultName) ? keyVaultName : '${abbrs.keyVault}${resourceToken}'
  scope: resourceGroup
  params: {
    name: !empty(keyVaultName) ? keyVaultName : '${abbrs.keyVault}${resourceToken}'
    location: location
    tags: union(tags, {})
    privateEndpointSubnetId: virtualNetwork.outputs.serviceSubnetId
    virtualNetworkId: virtualNetwork.outputs.virtualNetworkId
    roleAssignments: [
      {
        principalId: managedIdentity.outputs.principalId
        roleDefinitionId: keyVaultAdministrator.id
      }
      {
        principalId: managedIdentity.outputs.principalId
        roleDefinitionId: keyVaultSecretsOfficer.id
      }
      {
        principalId: managedIdentity.outputs.principalId
        roleDefinitionId: keyVaultSecretsUser.id
      }
      {
        principalId: managedIdentity.outputs.principalId
        roleDefinitionId: keyVaultCertificatesOfficer.id
      }
      {
        principalId: managedIdentity.outputs.principalId
        roleDefinitionId: owner.id
      }
    ]
    apimPublicIpAddress: virtualNetwork.outputs.apimPublicIpAddress
  }
}

module certificate './core/key-vault-certificate.bicep' = {
  scope: resourceGroup
  name: !empty(certificateName) ? certificateName : '${abbrs.certificate}${resourceToken}'
  dependsOn: [ managedIdentity ]
  params: {
    location: location
    certificatename: !empty(certificateName) ? certificateName : '${abbrs.certificate}${resourceToken}'
    dnsname: dnsName
    vaultname: keyVault.outputs.name
    identityResourceId: managedIdentity.outputs.id
  }
}

module openAI './core/cognitive-services.bicep' = [for openAIInstance in openAIInstances: {
  name: !empty(openAIInstance.name) ? openAIInstance.name! : '${abbrs.cognitiveServices}${resourceToken}-${openAIInstance.suffix}'
  scope: resourceGroup
  params: {
    name: !empty(openAIInstance.name) ? openAIInstance.name! : '${abbrs.cognitiveServices}${resourceToken}-${openAIInstance.suffix}'
    location: openAIInstance.location
    tags: union(tags, {})
    privateEndpointSubnetId: virtualNetwork.outputs.serviceSubnetId
    virtualNetworkId: virtualNetwork.outputs.virtualNetworkId
    sku: {
      name: 'S0'
    }
    kind: 'OpenAI'
    deployments: [
      {
        name: 'gpt-35-turbo'
        model: {
          format: 'OpenAI'
          name: 'gpt-35-turbo'
          version: '0301'
        }
        sku: {
          name: 'Standard'
          capacity: 1
        }
      }
      {
        name: 'text-embedding-ada-002'
        model: {
          format: 'OpenAI'
          name: 'text-embedding-ada-002'
          version: '2'
        }
        sku: {
          name: 'Standard'
          capacity: 1
        }
      }
    ]
    keyVaultSecrets: {
      name: keyVault.outputs.name
      secrets: [
        {
          property: 'PrimaryKey'
          name: 'OPENAI-API-KEY-${toUpper(openAIInstance.suffix)}'
        }
      ]
    }
  }
}]

module apiManagement './core/api-management.bicep' = {
  name: !empty(apiManagementName) ? apiManagementName : '${abbrs.apiManagementService}${resourceToken}'
  scope: resourceGroup
  params: {
    name: !empty(apiManagementName) ? apiManagementName : '${abbrs.apiManagementService}${resourceToken}'
    location: location
    tags: union(tags, {})
    sku: {
      name: 'Developer'
      capacity: 1
    }
    publisherEmail: apiManagementPublisherEmail
    publisherName: apiManagementPublisherName
    apiManagementIdentityId: managedIdentity.outputs.id
    apiManagementIdentityClientId: managedIdentity.outputs.clientId
    apimSubnetId: virtualNetwork.outputs.apimSubnetId
    keyvaultid:  '${keyVault.outputs.uri}secrets/${certificate.outputs.certificateName}' // '${keyVault.outputs.name}.privatelink.vaultcore.azure.net/secrets/${certificate.outputs.certificateName}'
    dnsName: certificate.outputs.dnsname
    publicIpAddressId: virtualNetwork.outputs.apimPublicIpId
  }
}

module openAIApiKeyNamedValue './core/api-management-key-vault-named-value.bicep' = [for openAIInstance in openAIInstances: {
  name: 'NV-OPENAI-API-KEY-${toUpper(openAIInstance.suffix)}'
  scope: resourceGroup
  params: {
    name: 'OPENAI-API-KEY-${toUpper(openAIInstance.suffix)}'
    displayName: 'OPENAI-API-KEY-${toUpper(openAIInstance.suffix)}'
    apiManagementName: apiManagement.outputs.name
    apiManagementIdentityClientId: managedIdentity.outputs.clientId
    keyVaultSecretUri: '${keyVault.outputs.uri}secrets/OPENAI-API-KEY-${toUpper(openAIInstance.suffix)}'
  }
}]

module openAIApi './core/api-management-openapi-api.bicep' = {
  name: '${apiManagement.name}-api-openai'
  scope: resourceGroup
  params: {
    name: 'openai'
    apiManagementName: apiManagement.outputs.name
    path: '/openai'
    format: 'openapi-link'
    displayName: 'OpenAI'
    value: 'https://raw.githubusercontent.com/Azure/azure-rest-api-specs/main/specification/cognitiveservices/data-plane/AzureOpenAI/inference/preview/2023-07-01-preview/inference.json'
  }
}

module apiSubscription './core/api-management-subscription.bicep' = {
  name: '${apiManagement.name}-subscription-openai'
  scope: resourceGroup
  params: {
    name: 'openai-sub'
    apiManagementName: apiManagement.outputs.name
    displayName: 'OpenAI API Subscription'
    scope: '/apis/${openAIApi.outputs.name}'
  }
}

module openAIApiBackend './core/api-management-backend.bicep' = [for (item, index) in openAIInstances: {
  name: '${apiManagement.name}-backend-openai-${item.suffix}'
  scope: resourceGroup
  params: {
    name: 'OPENAI${toUpper(item.suffix)}'
    apiManagementName: apiManagement.outputs.name
    url: openAI[index].outputs.endpoint
  }
}]

module loadBalancingPolicy './core/api-management-policy.bicep' = {
  name: '${apiManagement.name}-policy-load-balancing'
  scope: resourceGroup
  params: {
    apiManagementName: apiManagement.outputs.name
    apiName: openAIApi.outputs.name
    format: 'rawxml'
    value: loadTextContent('./policies/round-robin-policy.xml') 
  }
}

output resourceGroupInstance object = {
  id: resourceGroup.id
  name: resourceGroup.name
}

output managedIdentityInstance object = {
  id: managedIdentity.outputs.id
  name: managedIdentity.outputs.name
  principalId: managedIdentity.outputs.principalId
  clientId: managedIdentity.outputs.clientId
}

output keyVaultInstance object = {
  id: keyVault.outputs.id
  name: keyVault.outputs.name
  uri: keyVault.outputs.uri
}

output openAIInstances array = [for (item, index) in openAIInstances: {
  name: openAI[index].outputs.name
  host: openAI[index].outputs.host
  endpoint: openAI[index].outputs.endpoint
  location: item.location
  suffix: item.suffix
}]

output apiManagementInstance object = {
  id: apiManagement.outputs.id
  name: apiManagement.outputs.name
  gatewayUrl: apiManagement.outputs.gatewayUrl
  subscriptionName: apiSubscription.outputs.name
}
