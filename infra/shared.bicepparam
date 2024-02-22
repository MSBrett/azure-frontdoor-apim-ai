using './shared.bicep'

param logAnalyticsWorkspaceName = 'contosoworkspace'
param location = 'westus'
param logAnalyticsResourceGroupName = 'Observability'
param azureFrontDoorResourceGroupName = 'GlobalNetworking'
param dnsZoneName = 'ai.contoso.com'
param tags = {
  application: 'Shared-Services'
  environment: 'development'
}

