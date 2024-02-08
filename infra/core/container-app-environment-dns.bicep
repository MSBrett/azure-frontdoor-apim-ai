param defaultDomain string
param ipv4Address string
param virtualNetworkId string

resource privateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: defaultDomain
  location: 'global'
  properties: {
  }
}

resource wildcardRecord 'Microsoft.Network/privateDnsZones/A@2020-06-01' = {
  parent: privateDnsZone
  name: '*'
  properties: {
    ttl: 3600
    aRecords: [
      {
        ipv4Address: ipv4Address
      }
    ]
  }
}

/*
// probably not needed
resource domainRecord 'Microsoft.Network/privateDnsZones/A@2020-06-01' = {
  parent: privateDnsZone
  name: '@'
  properties: {
    ttl: 3600
    aRecords: [
      {
        ipv4Address: ipv4Address
      }
    ]
  }
}
*/

resource privateDnsZoneLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: privateDnsZone
  name: '${privateDnsZone.name}-link'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: virtualNetworkId
    }
  }
}
