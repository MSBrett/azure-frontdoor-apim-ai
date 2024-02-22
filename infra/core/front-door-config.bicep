@description('The name of the Front Door endpoint to create. This must be globally unique.')
param frontDoorConfigName string
param frontDoorProfileName string
param azureDnsZone string
param azureDnsName string
@description('Required.  The hostname of the backend API to route to.')
param apiEndpointHostName string

@description('The name of the SKU to use when creating the Front Door profile.')
@allowed([
  'Standard_AzureFrontDoor'
  'Premium_AzureFrontDoor'
])
param frontDoorSkuName string = 'Standard_AzureFrontDoor'

@description('The mode that the WAF should be deployed using. In \'Prevention\' mode, the WAF will block requests it detects as malicious. In \'Detection\' mode, the WAF will not block requests and will simply log the request.')
@allowed([
  'Detection'
  'Prevention'
])
param wafMode string = 'Prevention'

@description('The IP address ranges to block. Individual IP addresses can be specified as-is. Ranges should be specified using CIDR notation.')
param ipAddressRangesToAllow array

param pathToMatch string = '/*'

resource dnsZone 'Microsoft.Network/dnsZones@2018-05-01' existing = {
  name: azureDnsZone
}

resource frontDoorProfile 'Microsoft.Cdn/profiles@2023-07-01-preview' existing = {
  name: frontDoorProfileName
}

resource customDomain 'Microsoft.Cdn/profiles/customDomains@2023-07-01-preview' = {
  parent: frontDoorProfile
  name: replace('${azureDnsName}.${azureDnsZone}','.', '-')
  properties: {
    azureDnsZone: {
      id: dnsZone.id
    }
    hostName: '${azureDnsName}.${azureDnsZone}'
    tlsSettings: {
      certificateType: 'ManagedCertificate'
      minimumTlsVersion: 'TLS12'
    }
  }
}

resource frontDoorEndpoint 'Microsoft.Cdn/profiles/afdEndpoints@2023-07-01-preview' = {
  name: frontDoorConfigName
  parent: frontDoorProfile
  dependsOn: [
    customDomain
  ]
  location: 'global'
  properties: {
    enabledState: 'Enabled'
  }
}

resource cnameRecord 'Microsoft.Network/dnsZones/CNAME@2018-05-01' = {
  parent: dnsZone
  name: azureDnsName
  properties: {
    TTL: 1800
    CNAMERecord: {
      cname: frontDoorEndpoint.properties.hostName
    }
  }
}

resource validationTxtRecord 'Microsoft.Network/dnsZones/TXT@2018-05-01' = {
  parent: dnsZone
  name: '_dnsauth.${azureDnsName}'
  properties: {
    TTL: 1800
    TXTRecords: [
      {
        value: [
          customDomain.properties.validationProperties.validationToken
        ]
      }
    ]
  }
}

resource frontDoorOriginGroup 'Microsoft.Cdn/profiles/originGroups@2023-07-01-preview' = {
  name: frontDoorConfigName
  parent: frontDoorProfile
  properties: {
    loadBalancingSettings: {
      sampleSize: 4
      successfulSamplesRequired: 3
      additionalLatencyInMilliseconds: 0
    }
    sessionAffinityState: 'Disabled'
  }
}

resource frontDoorOrigin 'Microsoft.Cdn/profiles/originGroups/origins@2023-07-01-preview' = {
  name: frontDoorConfigName
  parent: frontDoorOriginGroup
  properties: {
    hostName: apiEndpointHostName
    httpPort: 80
    httpsPort: 443
    originHostHeader: apiEndpointHostName
    priority: 1
    weight: 1000
    enforceCertificateNameCheck: true
    enabledState: 'Enabled'
  }
}

resource frontDoorRoute 'Microsoft.Cdn/profiles/afdEndpoints/routes@2023-07-01-preview' = {
  name: frontDoorConfigName
  parent: frontDoorEndpoint
  dependsOn: [
    frontDoorOrigin // This explicit dependency is required to ensure that the origin group is not empty when the route is created.
  ]
  properties: {
    customDomains: [
      {
        id: customDomain.id
      }
    ]
    originGroup: {
      id: frontDoorOriginGroup.id
    }
    supportedProtocols: [
      'Http'
      'Https'
    ]
    patternsToMatch: [
      pathToMatch
    ]
    forwardingProtocol: 'HttpsOnly'
    linkToDefaultDomain: 'Enabled'
    httpsRedirect: 'Enabled'
  }
}

resource wafPolicy 'Microsoft.Network/FrontDoorWebApplicationFirewallPolicies@2022-05-01' = {
  name: frontDoorConfigName
  location: 'global'
  sku: {
    name: frontDoorSkuName
  }
  properties: {
    policySettings: {
      enabledState: 'Enabled'
      mode: wafMode
    }
    customRules: {
      rules: [
        {
          name: 'AllowTrafficFromIPRanges'
          priority: 111
          enabledState: 'Enabled'
          ruleType: 'MatchRule'
          action: 'Allow'
          matchConditions: [
            {
              matchVariable: 'RemoteAddr'
              operator: 'IPMatch'
              matchValue: ipAddressRangesToAllow
            }
          ]
        }
        {
          name: 'DefaultDeny'
          priority: 999
          enabledState: 'Enabled'
          ruleType: 'MatchRule'
          action: 'Block'
          matchConditions: [
            {
              matchVariable: 'RemoteAddr'
              operator: 'IPMatch'
              matchValue: ['0.0.0.0/0']
            }
          ]
        }
      ]
    }
  }
}

resource frontDoorSecurityPolicy 'Microsoft.Cdn/profiles/securityPolicies@2021-06-01' = {
  parent: frontDoorProfile
  name: frontDoorConfigName
  properties: {
    parameters: {
      type: 'WebApplicationFirewall'
      wafPolicy: {
        id: wafPolicy.id
      }
      associations: [
        {
          domains: [
            {
              id: frontDoorEndpoint.id
            }
          ]
          patternsToMatch: [
            '/*'
          ]
        }
      ]
    }
  }
}

output frontDoorEndpointHostName string = frontDoorEndpoint.properties.hostName
output frontDoorId string = frontDoorProfile.properties.frontDoorId
