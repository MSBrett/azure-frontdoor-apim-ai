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

var frontDoorProfileName = frontDoorEndpointName
var frontDoorOriginGroupName = 'sccOriginGroup'
var frontDoorOriginName = 'sccOrigin'
var frontDoorRouteName = 'sccRoute'
var frontDoorRuleSetName = 'sccRuleSet'

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
          sourcePattern: '/v1/generate'
          typeName: 'DeliveryRuleUrlRewriteActionParameters'
        }
      }
    ]
    conditions: [
      {
        name: 'UrlPath'
        parameters: {
          matchValues: [
            '/v1/generate'
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
          sourcePattern: '/v1/embed'
          typeName: 'DeliveryRuleUrlRewriteActionParameters'
        }
      }
    ]
    conditions: [
      {
        name: 'UrlPath'
        parameters: {
          matchValues: [
            '/v1/embed'
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

output frontDoorEndpointHostName string = frontDoorEndpoint.properties.hostName
