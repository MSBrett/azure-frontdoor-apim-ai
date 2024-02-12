targetScope = 'subscription'

@minLength(1)
@maxLength(64)
@description('Name of the workload which is used to generate a short unique hash used in all resources.')
param workloadName string

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

@description('Name of the OpenAI service. If empty, a unique name will be generated.')
param openAIName string = ''

@description('Name of the API Management service. If empty, a unique name will be generated.')
param apiManagementName string = ''
@description('Email address for the API Management service publisher.')
param apiManagementPublisherEmail string
@description('Name of the API Management service publisher.')
param apiManagementPublisherName string

@description('Id of the log analytics workspace.')
param logAnalyticsWorkspaceId string

param text_embeddings_inference_container string = 'docker.io/snpsctg/tei-bge:latest'

param publishedApiVersion string = 'v1'

var abbrs = loadJsonContent('./abbreviations.json')
var roles = loadJsonContent('./roles.json')
var resourceToken = toLower(uniqueString(subscription().id, workloadName, location))

resource resourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: !empty(resourceGroupName) ? resourceGroupName : '${abbrs.resourceGroup}${workloadName}'
  location: location
  tags: union(tags, {})
}

module virtualNetwork 'core/virtual-network.bicep' = {
  name: '${abbrs.virtualNetwork}${resourceToken}'
  scope: resourceGroup
  params: {
    location: location
    tags: union(tags, {})
    virtualNetworkAddressPrefix: virtualNetworkAddressPrefix
    bastionHostName: '${abbrs.virtualNetwork}${resourceToken}'
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

/*
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
*/

module openAI './core/cognitive-services.bicep' = {
  name: !empty(openAIName) ? openAIName! : '${abbrs.cognitiveServices}${resourceToken}-aoai'
  scope: resourceGroup
  params: {
    name: !empty(openAIName) ? openAIName! : '${abbrs.cognitiveServices}${resourceToken}-aoai'
    location: location
    tags: union(tags, {})
    publicNetworkAccess: 'Disabled'
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
          name: 'OPENAI-API-KEY'
        }
      ]
    }
  }
}

module containerAppEnv 'core/container-app-environment.bicep' = {
  name: '${abbrs.containerAppsEnvironment}${resourceToken}'
  scope: resourceGroup
  params: {
    location: location
    containerAppEnvSubnetId: virtualNetwork.outputs.containerAppEnvSubnetId
    containerAppEnvName: '${abbrs.containerAppsEnvironment}${resourceToken}'
  }
}

module text_embeddings_inference 'core/container-app.bicep' = {
  name: '${abbrs.containerApp}${resourceToken}'
  scope: resourceGroup
  params: {
    location: location
    containerAppName: '${abbrs.containerApp}${resourceToken}'
    containerImage: text_embeddings_inference_container
    cpuCore: '2'
    targetPort: 80
    memorySize: '4'
    containerAppEnvId: containerAppEnv.outputs.id
    minReplicas: 3
  }
}

module containerAppDns 'core/container-app-environment-dns.bicep' = {
  name: '${abbrs.containerAppsEnvironment}${resourceToken}-dns'
  scope: resourceGroup
  params: {
    defaultDomain: containerAppEnv.outputs.defaultDomain
    ipv4Address: containerAppEnv.outputs.staticIp
    virtualNetworkId: virtualNetwork.outputs.virtualNetworkId
  }
}

module apiManagement './core/api-management.bicep' = {
  name: !empty(apiManagementName) ? apiManagementName : '${abbrs.apiManagementService}${resourceToken}'
  scope: resourceGroup
  dependsOn: [openAI]
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
    apimSubnetId: virtualNetwork.outputs.apimSubnetId
    // keyvaultid:  '${keyVault.outputs.uri}secrets/${certificate.outputs.certificateName}' // '${keyVault.outputs.name}.privatelink.vaultcore.azure.net/secrets/${certificate.outputs.certificateName}'
    // dnsName: certificate.outputs.dnsname
    publicIpAddressId: virtualNetwork.outputs.apimPublicIpId
  }
}

module apiSubscription './core/api-management-subscription.bicep' = {
  name: '${apiManagement.name}-subscription-openai'
  scope: resourceGroup
  params: {
    name: 'openai-sub'
    apiManagementName: apiManagement.outputs.name
    displayName: 'SCC API Subscription'
    scope: '/apis'
  }
}

module openAIApiKeyNamedValue './core/api-management-key-vault-named-value.bicep' = {
  name: 'NV-OPENAI-API-KEY'
  scope: resourceGroup
  dependsOn: [ keyVault, openAI ]
  params: {
    name: 'OPENAI-API-KEY'
    displayName: 'OPENAI-API-KEY'
    apiManagementName: apiManagement.outputs.name
    apiManagementIdentityClientId: managedIdentity.outputs.clientId
    keyVaultSecretUri: '${keyVault.outputs.uri}secrets/OPENAI-API-KEY'
  }
}

module openAIApi './core/api-management-api.bicep' = {
  name: '${apiManagement.name}-api-openai'
  scope: resourceGroup
  params: {
    name: 'openai'
    apiManagementName: apiManagement.outputs.name
    path: '/openai'
    format: 'openapi-link'
    displayName: 'OpenAI'
    value: 'https://raw.githubusercontent.com/Azure/azure-rest-api-specs/main/specification/cognitiveservices/data-plane/AzureOpenAI/inference/preview/2023-07-01-preview/inference.json'
    serviceUrl: 'https://${openAI.outputs.name}.${openAI.outputs.privateDnsZoneName}'
  }
}

module openAiPolicy './core/api-management-policy.bicep' = {
  name: '${apiManagement.name}-policy-openAI'
  scope: resourceGroup
  params: {
    apiManagementName: apiManagement.outputs.name
    apiName: openAIApi.outputs.name
    format: 'rawxml'
    value: loadTextContent('./policies/openai.xml') 
  }
}

module teiApi './core/api-management-api.bicep' = {
  name: '${apiManagement.name}-api-tei'
  scope: resourceGroup
  params: {
    name: 'tei'
    apiManagementName: apiManagement.outputs.name
    path: '/${publishedApiVersion}'
    format: 'openapi-link'
    displayName: 'Text-Embeddings-Inference'
    value: 'https://huggingface.github.io/text-embeddings-inference/openapi.json'
    serviceUrl: 'https://${text_embeddings_inference.outputs.containerAppFQDN}'
  }
}

module frontDoor './core/front-door.bicep' = {
  name: '${abbrs.frontDoorProfile}${resourceToken}'
  scope: resourceGroup
  params: {
    frontDoorEndpointName: '${abbrs.frontDoorProfile}${resourceToken}'
    tags: union(tags, {})
    apiEndpointHostName: apiManagement.outputs.gatewayHostName
    frontDoorSkuName: 'Standard_AzureFrontDoor'
  }
}

// Outputs
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

output openAIInstance object = {
  name: openAI.outputs.name
  host: openAI.outputs.host
  endpoint: openAI.outputs.endpoint
  location: location
  suffix: 'aoai'
}

output apiManagementInstance object = {
  id: apiManagement.outputs.id
  name: apiManagement.outputs.name
  gatewayUrl: apiManagement.outputs.gatewayUrl
  sccApiSubscription: apiSubscription.outputs.name
}

