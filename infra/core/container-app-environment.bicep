@description('Specifies the name of the container app environment.')
param containerAppEnvName string

@description('Specifies the location for all resources.')
param location string

@description('The subnet to delegate to the container app environment')
param containerAppEnvSubnetId string

resource containerAppEnv 'Microsoft.App/managedEnvironments@2022-03-01' = {
  name: containerAppEnvName
  location: location
  properties: {
    vnetConfiguration: {
      infrastructureSubnetId: containerAppEnvSubnetId
      internal: true
    }
  }
}

output id string = containerAppEnv.id
output name string = containerAppEnv.name
output defaultDomain string = containerAppEnv.properties.defaultDomain
output staticIp string = containerAppEnv.properties.staticIp
