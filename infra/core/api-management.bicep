@description('Name of the resource.')
param name string
// @description('The DNS name of the API Management service. Must be a valid domain name.')
// param dnsName string
@description('Location to deploy the resource. Defaults to the location of the resource group.')
param location string = resourceGroup().location
@description('Tags for the resource.')
param tags object = {}
@description('ID for the Managed Identity associated with the API Management resource.')
param apiManagementIdentityId string

param publicIpAddressId string

type skuInfo = {
  name: 'Developer' | 'Standard' | 'Premium' | 'Basic' | 'Consumption' | 'Isolated'
  capacity: int
}

param apimSubnetId string
// param keyvaultid string

@description('Email address of the owner for the API Management resource.')
@minLength(1)
param publisherEmail string
@description('Name of the owner for the API Management resource.')
@minLength(1)
param publisherName string
@description('API Management SKU. Defaults to Developer, capacity 1.')
param sku skuInfo = {
  name: 'Developer'
  capacity: 1
}

resource apiManagement 'Microsoft.ApiManagement/service@2023-03-01-preview' = {
  name: name
  location: location
  tags: tags
  sku: sku
  identity: {
    type: 'SystemAssigned, UserAssigned'
    userAssignedIdentities: {
      '${apiManagementIdentityId}': {}
    }
  }
  properties: {
    publisherEmail: publisherEmail
    publisherName: publisherName
    virtualNetworkType: 'External'
    publicIpAddressId: publicIpAddressId
    // natGatewayState: 'Enabled'
    virtualNetworkConfiguration: {
      subnetResourceId: apimSubnetId
    }
    hostnameConfigurations: [
      /*{
        type: 'Proxy'
        hostName: dnsName
        keyVaultId: keyvaultid
        identityClientId: apiManagementIdentityClientId
        defaultSslBinding: true
      }*/
    ]
    customProperties: {
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Ciphers.TLS_ECDHE_RSA_WITH_AES_256_CBC_SHA': 'false'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Ciphers.TLS_ECDHE_RSA_WITH_AES_128_CBC_SHA': 'false'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Ciphers.TLS_RSA_WITH_AES_128_GCM_SHA256': 'false'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Ciphers.TLS_RSA_WITH_AES_256_CBC_SHA256': 'false'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Ciphers.TLS_RSA_WITH_AES_128_CBC_SHA256': 'false'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Ciphers.TLS_RSA_WITH_AES_256_CBC_SHA': 'false'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Ciphers.TLS_RSA_WITH_AES_128_CBC_SHA': 'false'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Ciphers.TripleDes168': 'false'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Protocols.Tls10': 'false'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Protocols.Tls11': 'false'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Protocols.Ssl30': 'false'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Backend.Protocols.Tls10': 'false'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Backend.Protocols.Tls11': 'false'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Backend.Protocols.Ssl30': 'false'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Protocols.Server.Http2': 'true'
    }
  }
}

@description('ID for the deployed API Management resource.')
output id string = apiManagement.id
@description('Name for the deployed API Management resource.')
output name string = apiManagement.name
@description('Gateway URL for the deployed API Management resource.')
output gatewayUrl string = apiManagement.properties.gatewayUrl

output gatewayHostName string = apiManagement.properties.hostnameConfigurations[0].hostName
