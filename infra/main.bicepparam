using './main.bicep'

param workloadName = 'contoso'
param location = 'eastus'
param tags = {
  application: 'Contoso-App'
  customer: 'contoso'
  environment: 'development'
}
param ipAddressRangesToAllow = [
  '1.1.1.1'
]
param virtualNetworkAddressPrefix = '10.4.0.0/22'
param apiManagementPublisherEmail = 'info@microsoft.com'
param apiManagementPublisherName = 'info@microsoft.com'
param apiPathSuffix = '/api/v1'

// Created by the shared bicep file
param logAnalyticsWorkspaceId = '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/Observability/providers/Microsoft.OperationalInsights/workspaces/contosoworkspace'
param frontDoorProfileName = 'afd-contoso'
param frontDoorResourceGroupName = 'GlobalNetworking'
param frontDoorSubscriptionId = '00000000-0000-0000-0000-000000000000'
param dnsZoneName = 'ai.contoso.com'
