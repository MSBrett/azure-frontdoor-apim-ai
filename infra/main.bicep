targetScope = 'subscription'

@minLength(1)
@maxLength(64)
@description('Required. Name of the workload which is used to generate a short unique hash used in all resources.')
param workloadName string = 'fabrikam'

@minLength(1)
@description('Required. Primary location for all resources.')
param location_aks string = 'westus3'

@minLength(1)
@description('Required. Primary location for all resources.')
param location string  = 'eastus'

@description('Required. Email address for the API Management service publisher.')
param apiManagementPublisherEmail string = 'info@contoso.com'

@description('Required. Name of the API Management service publisher.')
param apiManagementPublisherName string = 'info@contoso.com'

@description('Name of the resource group. If empty, a unique name will be generated.')
param resourceGroupName string = ''

@description('Tags for all resources.')
param tags object = {}

@description('Address space for the workload.  A /23 is required for the workload.')
param virtualNetworkAddressPrefix string = '10.4.0.0/22'

@description('A list of IP ranges to accept connections from.')
param ipAddressRangesToAllow array = ['0.0.0.0/0']

@description('Name of the Managed Identity. If empty, a unique name will be generated.')
param managedIdentityName string = ''

@description('Name of the Key Vault. If empty, a unique name will be generated.')
param keyVaultName string = ''

@description('Name of the OpenAI service. If empty, a unique name will be generated.')
param openAIName string = ''

@description('Name of the API Management service. If empty, a unique name will be generated.')
param apiManagementName string = ''

@description('Required.  Id of the log analytics workspace.')
param logAnalyticsWorkspaceId string

@description('Required.  Name of the azure front door profile.')
param frontDoorProfileName string

@description('Required.  Resource group containing the azure front door profile.')
param frontDoorResourceGroupName string = 'GlobalNetworking'

@description('Required.  Subscription containing the azure front door profile.')
param frontDoorSubscriptionId string = subscription().id

@description('Required.  Name of the custom DNS zone to use for the workload.')
param dnsZoneName string = 'ai.contoso.com'

@description('Enable purge protection for the Key Vault. Default is true.')
param enablePurgeProtection bool = false

param deployJumpBox bool = false

@description('Path to putlish the api to. Default is /workloadName/v1.')
param apiPathSuffix string = '/api/v1'

@description('SKU for APIM. Default is Premium.')
param apimsku string = 'Premium'
@description('Capacity for APIM. Default is 1.')
param apimskuCapacity int = 1

@description('Array of groups to be granted AKS cluster access.')
param aadGroupdIds array = []
param kubernetesVersion string = '1.29.0'
param containerYaml string = 'https://raw.githubusercontent.com/MSBrett/azure-frontdoor-apim-ai/main/infra/yaml/deployment.yaml'

@allowed([
  'Regular'
  'Spot'
])
param gpuScaleSetPriority string = 'Regular'
@allowed([
  'Standard_NC24ads_A100_v4'
  'Standard_NC48ads_A100_v4'
  'Standard_NC96ads_A100_v4'
])
param gpuPoolVmSize string = 'Standard_NC24ads_A100_v4'

@allowed([
  'Standard_D2s_v5'
  'Standard_D4s_v5'
  'Standard_D8s_v5'
  'Standard_D2s_v4'
  'Standard_D4s_v4'
  'Standard_D8s_v4'
])
param defaultPoolVmSize string = 'Standard_D2s_v5'

var abbrs = loadJsonContent('./abbreviations.json')
var roles = loadJsonContent('./roles.json')
var resourceToken = toLower(uniqueString(subscription().id, workloadName, location))
var safeWorkloadName = replace(replace(replace('${workloadName}', '-', ''), '_', ''), ' ', '')
var apiPolicy = loadTextContent('./policies/api.xml')
var openAiPolicy = loadTextContent('./policies/openai.xml')

var rewriteUrl_generate = '/openai/deployments/gpt-35-turbo/chat/completions?api-version=2023-07-01-preview'
var rewriteUrl_embed = '/openai/deployments/text-embedding-ada-002/embeddings?api-version=2023-07-01-preview'
var rewriteUrl_rerank = '/predict'
var adminUsername = 'admin${resourceToken}'

resource resourceGroup 'Microsoft.Resources/resourceGroups@2022-09-01' = {
  name: !empty(resourceGroupName) ? resourceGroupName : '${abbrs.resourceGroup}${workloadName}'
  location: location
  tags: union(tags, {})
}

resource resourceGroup_aks 'Microsoft.Resources/resourceGroups@2022-09-01' = {
  name: !empty(resourceGroupName) ? '${resourceGroupName}-gpu' : '${abbrs.resourceGroup}${workloadName}-aks'
  location: location_aks
  tags: union(tags, {})
}

module virtualNetwork 'core/virtual-network.bicep' = {
  name: '${abbrs.virtualNetwork}${resourceToken}'
  scope: resourceGroup
  params: {
    location: location
    tags: union(tags, {})
    virtualNetworkAddressPrefix: cidrSubnet(virtualNetworkAddressPrefix, 24, 0)
    bastionHostName: '${abbrs.virtualNetwork}${resourceToken}'
    publicIpName: '${abbrs.publicIPAddress}${resourceToken}'
    virtualNetworkName: '${abbrs.virtualNetwork}${resourceToken}'
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId
    deployBastion: true
  }
}

module virtualNetwork_aks 'core/virtual-network-spoke.bicep' = {
  name: '${abbrs.virtualNetwork}${resourceToken}_aks'
  scope: resourceGroup_aks
  params: {
    location: location_aks
    tags: union(tags, {})
    virtualNetworkAddressPrefix: cidrSubnet(virtualNetworkAddressPrefix, 23, 1)
    virtualNetworkName: '${abbrs.virtualNetwork}${resourceToken}_aks'
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId
  }
}

module virtualNetwork_peering_1 'core/virtual-network-peering.bicep' = {
  name: '${abbrs.virtualNetwork}${resourceToken}-peering-1'
  scope: resourceGroup
  params: {
    virtualNetworkName1: virtualNetwork.outputs.virtualNetworkName
    virtualNetworkName2: virtualNetwork_aks.outputs.virtualNetworkName
    virtualNetworkRgName2: resourceGroup_aks.name
  }
}

module virtualNetwork_peering_2 'core/virtual-network-peering.bicep' = {
  name: '${abbrs.virtualNetwork}${resourceToken}-peering-2'
  scope: resourceGroup_aks
  params: {
    virtualNetworkName1: virtualNetwork_aks.outputs.virtualNetworkName
    virtualNetworkName2: virtualNetwork.outputs.virtualNetworkName
    virtualNetworkRgName2: resourceGroup.name
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

module keyVault './core/key-vault-private.bicep' = {
  name: !empty(keyVaultName) ? keyVaultName : '${abbrs.keyVault}${resourceToken}'
  scope: resourceGroup
  params: {
    name: !empty(keyVaultName) ? keyVaultName : '${abbrs.keyVault}${resourceToken}'
    location: location
    tags: union(tags, {})
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId
    privateEndpointSubnetId: virtualNetwork.outputs.serviceSubnetId
    virtualNetworkId: virtualNetwork.outputs.virtualNetworkId
    enablePurgeProtection: enablePurgeProtection
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
    publicIpAddressToAllow: virtualNetwork.outputs.apimPublicIpAddress
  }
}

module openAI './core/cognitive-services.bicep' = {
  name: !empty(openAIName) ? openAIName! : '${abbrs.cognitiveServices}${resourceToken}-aoai'
  scope: resourceGroup
  params: {
    name: !empty(openAIName) ? openAIName! : '${abbrs.cognitiveServices}${resourceToken}-aoai'
    location: location
    tags: union(tags, {})
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId
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
          capacity: 30
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
          capacity: 30
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

module jumpbox 'core/virtual-machine.bicep' = if (deployJumpBox) {
  name: '${abbrs.virtualMachine}${resourceToken}'
  scope: resourceGroup
  params: {
    location: location
    subnetId: virtualNetwork.outputs.serviceSubnetId
    vmName: '${abbrs.virtualMachine}${resourceToken}'
    vmSize: 'Standard_D2s_v4'
    adminUsername: adminUsername
    publicKey: loadTextContent('../../../.ssh/id_rsa.pub')
  }
}

var groupIds = concat(aadGroupdIds, [managedIdentity.outputs.principalId])
module aks 'core/aks-cluster.bicep' = {
  name: 'aks'
  scope: resourceGroup_aks
  params: {
    location: location_aks
    aadGroupdIds: groupIds
    clusterName: '${abbrs.aksCluster}${resourceToken}'
    kubernetesVersion: kubernetesVersion
    logworkspaceid: logAnalyticsWorkspaceId
    subnetId: virtualNetwork_aks.outputs.workloadSubnetId
    vnetName: virtualNetwork_aks.outputs.virtualNetworkName
    nodeResourceGroupName: '${resourceGroup_aks.name}-mc'
    infraResourceGroupName: resourceGroup_aks.name
    gpuScaleSetPriority: gpuScaleSetPriority
    gpuPoolVmSize: gpuPoolVmSize
    defaultPoolVmSize: defaultPoolVmSize
    adminUsername: adminUsername
  }
}

module aksClusterAdminRole 'core/role.bicep' = {
  name: 'aks-cluster-admin-role'
  scope: resourceGroup_aks
  params: {
    principalId: managedIdentity.outputs.principalId
    resourceGroupName: resourceGroup_aks.name
    roleGuid: '3498e952-d568-435e-9b2c-8d77e338d7f7' // AKS RBAC Admin
  }
}

module deployContainer 'core/container-deployment.bicep' = {
  name: 'deployContainer'
  scope: resourceGroup_aks
  dependsOn: [
    aks
    aksClusterAdminRole
  ]
  params: {
    clusterName: aks.outputs.clusterName
    location: location_aks
    clusterResourceGroupName:resourceGroup_aks.name
    identityPrincipalId: managedIdentity.outputs.principalId
    identityResourceId: managedIdentity.outputs.id
    yamlFile: containerYaml
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
      name: apimsku
      capacity: apimskuCapacity
    }
    publisherEmail: apiManagementPublisherEmail
    publisherName: apiManagementPublisherName
    apiManagementIdentityId: managedIdentity.outputs.id
    apimSubnetId: virtualNetwork.outputs.apimSubnetId
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId
    publicIpAddressId: virtualNetwork.outputs.apimPublicIpId
  }
}

module apiSubscription './core/api-management-subscription.bicep' = {
  name: '${apiManagement.name}-subscription-openai'
  scope: resourceGroup
  params: {
    name: 'openai-sub'
    apiManagementName: apiManagement.outputs.name
    displayName: 'API Subscription'
    scope:  '/apis' //'/apis${apiPathSuffix}'
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

module api './core/api-management-api.bicep' = {
  name: '${apiManagement.name}-api'
  scope: resourceGroup
  params: {
    name: 'api'
    apiManagementName: apiManagement.outputs.name
    path: apiPathSuffix
    format: 'openapi+json'
    displayName: 'API'
    value: loadTextContent('./api/ka.openapi+json.json')
  }
}

module apiPolicy_generate './core/api-management-operation-policy.bicep' = {
  name: '${apiManagement.name}-policy-generate'
  scope: resourceGroup
  params: {
    apiManagementName: apiManagement.outputs.name
    apiName: api.outputs.name
    format: 'rawxml'
    value: replace(replace(replace(openAiPolicy, '<REWRITEURL>', rewriteUrl_generate) , '<SERVICEURL>', 'https://${openAI.outputs.name}.${openAI.outputs.privateDnsZoneName}'), '<FRONTDOORID>', frontDoor.outputs.frontDoorId)
    operationName: 'generate'
  }
}

module apiPolicy_embed './core/api-management-operation-policy.bicep' = {
  name: '${apiManagement.name}-policy-embed'
  scope: resourceGroup
  params: {
    apiManagementName: apiManagement.outputs.name
    apiName: api.outputs.name
    format: 'rawxml'
    value: replace(replace(replace(openAiPolicy, '<REWRITEURL>', rewriteUrl_embed) , '<SERVICEURL>', 'https://${openAI.outputs.name}.${openAI.outputs.privateDnsZoneName}'), '<FRONTDOORID>', frontDoor.outputs.frontDoorId)
    operationName: 'embed'
  }
}

module apiPolicy_predict './core/api-management-operation-policy.bicep' = {
  name: '${apiManagement.name}-policy-rerank'
  scope: resourceGroup
  params: {
    apiManagementName: apiManagement.outputs.name
    apiName: api.outputs.name
    format: 'rawxml'
    value: replace(replace(replace(apiPolicy, '<REWRITEURL>', rewriteUrl_rerank) , '<SERVICEURL>', 'http://10.4.2.111'), '<FRONTDOORID>', frontDoor.outputs.frontDoorId)
    operationName: 'rerank'
  }
}

resource frontDoorResourceGroup 'Microsoft.Resources/resourceGroups@2022-09-01' existing = {
  name: frontDoorResourceGroupName
  scope : subscription(frontDoorSubscriptionId)
}

module frontDoor './core/front-door-config.bicep' = {
  name: '${abbrs.frontDoorEndpoint}${resourceToken}'
  scope: frontDoorResourceGroup
  params: {
    frontDoorConfigName: '${safeWorkloadName}${resourceToken}'
    frontDoorProfileName : frontDoorProfileName
    apiEndpointHostName: apiManagement.outputs.gatewayHostName
    frontDoorSkuName: 'Premium_AzureFrontDoor'
    ipAddressRangesToAllow: ipAddressRangesToAllow
    pathToMatch: '${apiPathSuffix}/*'
    azureDnsZone: dnsZoneName
    azureDnsName: workloadName
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
  tenantId: managedIdentity.outputs.tenantId
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
/*
output apiManagementInstance object = {
  id: apiManagement.outputs.id
  name: apiManagement.outputs.name
  gatewayUrl: apiManagement.outputs.gatewayUrl
  apiSubscriptionName: apiSubscription.outputs.name
}
*/
