@description('The name of the Front Door endpoint to create. This must be globally unique.')
param frontDoorEndpointName string = 'afd-${uniqueString(resourceGroup().id)}'

@description('Required.  The hostname of the backend API to route to.')
param apiEndpointHostName string

param openAIApiVersion string = '2023-07-01-preview'

@description('Tags for all resources.')
param tags object = {}

@description('The name of the SKU to use when creating the Front Door profile.')
@allowed([
  'Standard_AzureFrontDoor'
  'Premium_AzureFrontDoor'
])
param frontDoorSkuName string = 'Standard_AzureFrontDoor'

param apiUrlSuffix string

@description('The mode that the WAF should be deployed using. In \'Prevention\' mode, the WAF will block requests it detects as malicious. In \'Detection\' mode, the WAF will not block requests and will simply log the request.')
@allowed([
  'Detection'
  'Prevention'
])
param wafMode string = 'Prevention'

@description('The IP address ranges to block. Individual IP addresses can be specified as-is. Ranges should be specified using CIDR notation.')
param ipAddressRangesToAllow array

var frontDoorProfileName = frontDoorEndpointName
var frontDoorOriginGroupName = 'sccOriginGroup'
var frontDoorOriginName = 'sccOrigin'
var frontDoorRouteName = 'sccRoute'
var frontDoorRuleSetName = 'sccRuleSet'
var frontDoorSecurityPolicyName = 'sccSecurityPolicy'

resource frontDoorProfile 'Microsoft.Cdn/profiles@2023-07-01-preview' = {
  name: frontDoorProfileName
  location: 'global'
  tags: tags
  sku: {
    name: frontDoorSkuName
  }
}

resource frontDoorEndpoint 'Microsoft.Cdn/profiles/afdEndpoints@2023-07-01-preview' = {
  name: frontDoorEndpointName
  parent: frontDoorProfile
  location: 'global'
  properties: {
    enabledState: 'Enabled'
  }
}

resource frontDoorOriginGroup 'Microsoft.Cdn/profiles/originGroups@2023-07-01-preview' = {
  name: frontDoorOriginGroupName
  parent: frontDoorProfile
  properties: {
    loadBalancingSettings: {
      sampleSize: 4
      successfulSamplesRequired: 3
    }
    healthProbeSettings: {
      probePath: '/'
      probeRequestType: 'HEAD'
      probeProtocol: 'Https'
      probeIntervalInSeconds: 100
    }
    sessionAffinityState: 'Enabled'
  }
}

resource frontDoorOrigin 'Microsoft.Cdn/profiles/originGroups/origins@2023-07-01-preview' = {
  name: frontDoorOriginName
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

resource frontDoorRuleSet 'Microsoft.Cdn/profiles/ruleSets@2023-07-01-preview' = {
  name: frontDoorRuleSetName
  parent: frontDoorProfile
}

resource generate 'Microsoft.Cdn/profiles/ruleSets/rules@2023-07-01-preview' = {
  name: 'generate'
  parent: frontDoorRuleSet
  properties: {
    actions: [
      {
        name: 'UrlRewrite'
        parameters: {
          destination: '/openai/deployments/gpt-35-turbo/chat/completions?api-version=${openAIApiVersion}'
          preserveUnmatchedPath: false
          sourcePattern: '${apiUrlSuffix}/generate'
          typeName: 'DeliveryRuleUrlRewriteActionParameters'
        }
      }
    ]
    conditions: [
      {
        name: 'UrlPath'
        parameters: {
          matchValues: [
            '${apiUrlSuffix}/generate'
          ]
          negateCondition: false
          operator: 'Contains'
          transforms: [
            'Lowercase'
          ]
          typeName: 'DeliveryRuleUrlPathMatchConditionParameters'
        }
      }
    ]
    matchProcessingBehavior: 'Stop'
    order: 1
  }
}

resource embed 'Microsoft.Cdn/profiles/ruleSets/rules@2023-07-01-preview' = {
  name: 'embed'
  dependsOn: [
    generate
  ]
  parent: frontDoorRuleSet
  properties: {
    actions: [
      {
        name: 'UrlRewrite'
        parameters: {
          destination: '/openai/deployments/text-embedding-ada-002/embeddings?api-version=${openAIApiVersion}'
          preserveUnmatchedPath: false
          sourcePattern: '${apiUrlSuffix}/embed'
          typeName: 'DeliveryRuleUrlRewriteActionParameters'
        }
      }
    ]
    conditions: [
      {
        name: 'UrlPath'
        parameters: {
          matchValues: [
            '${apiUrlSuffix}/embed'
          ]
          negateCondition: false
          operator: 'Contains'
          transforms: [
            'Lowercase'
          ]
          typeName: 'DeliveryRuleUrlPathMatchConditionParameters'
        }
      }
    ]
    matchProcessingBehavior: 'Stop'
    order: 2
  }
}

resource frontDoorRoute 'Microsoft.Cdn/profiles/afdEndpoints/routes@2023-07-01-preview' = {
  name: frontDoorRouteName
  parent: frontDoorEndpoint
  dependsOn: [
    frontDoorOrigin // This explicit dependency is required to ensure that the origin group is not empty when the route is created.
  ]
  properties: {
    originGroup: {
      id: frontDoorOriginGroup.id
    }
    supportedProtocols: [
      'Http'
      'Https'
    ]
    patternsToMatch: [
      '/*'
    ]
    ruleSets: [
      {
        id: frontDoorRuleSet.id
      }
    ]
    forwardingProtocol: 'HttpsOnly'
    linkToDefaultDomain: 'Enabled'
    httpsRedirect: 'Enabled'
  }
}

resource wafPolicy 'Microsoft.Network/frontDoorWebApplicationFirewallPolicies@2020-11-01' = {
  name: 'wafPolicy'
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
  name: frontDoorSecurityPolicyName
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
