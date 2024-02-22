@description('The name of the Front Door endpoint to create. This must be globally unique.')
param frontDoorConfigName string

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
