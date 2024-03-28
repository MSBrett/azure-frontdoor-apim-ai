// Parameters
@description('The Azure Region to deploy the resources into.')
param location string = resourceGroup().location

@description('The IP address range for all virtual networks to use.')
param virtualNetworkAddressPrefix string

@description('Tags you would like to be applied to all resources in this module.')
param tags object = {}

param virtualNetworkName string

param logAnalyticsWorkspaceId string = ''

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2023-02-01' = {
  name: virtualNetworkName
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        virtualNetworkAddressPrefix
      ]
    }
    subnets: [
      {
        name: 'Workload'
        properties: {
          addressPrefix: virtualNetworkAddressPrefix
          networkSecurityGroup: {
            id: workloadNsg.id
          }
          //routeTable: {
          //  id: defaultRouteTable.id
          //}
          serviceEndpoints:[
            {
              service: 'Microsoft.KeyVault'
            }
          ]
        }
      }
    ]
  }
}

resource workloadNsg 'Microsoft.Network/networkSecurityGroups@2023-04-01' = {
  name: 'workload-nsg'
  location: location
  properties: {
    securityRules: [ ]
  }
}

resource virtualNetworkDiagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (logAnalyticsWorkspaceId != '') {
  scope: virtualNetwork
  name: 'diagnosticSettingsConfig'
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

resource workloadNsgDiagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (logAnalyticsWorkspaceId != '') {
  scope: workloadNsg
  name: 'diagnosticSettingsConfig'
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      {
        category: 'NetworkSecurityGroupEvent'
        enabled: true
      }
      {
        category: 'NetworkSecurityGroupRuleCounter'
        enabled: true
      }
    ]
  }
}

/*
resource defaultRouteTable 'Microsoft.Network/routeTables@2023-04-01' = {
  name: 'default-rt'
  location: location
  tags: tags
  properties: {
    routes: [
      {
        name: 'default-route'
        properties: {
          addressPrefix: '0.0.0.0/0'
          nextHopType: 'virtualAppliance'
          nextHopIpAddress: '10.255.255.196'
        }
      }
    ]
  }
}
*/

output virtualNetworkName string = virtualNetwork.name
output virtualNetworkId string = virtualNetwork.id
output virtualNetworkAddressPrefix string = virtualNetwork.properties.addressSpace.addressPrefixes[0]

output workloadSubnetName string = virtualNetwork.properties.subnets[0].name
output workloadSubnetId string = virtualNetwork.properties.subnets[0].id
output workloadSubnetAddressPrefix string = virtualNetwork.properties.subnets[0].properties.addressPrefix
