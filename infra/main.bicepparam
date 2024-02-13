using './main.bicep'

param workloadName = 'contoso-ai'
param location = 'eastus'
param tags = {
  application: 'ai'
  customer: 'contoso'
  environment: 'development'
}
param ipAddressRangesToAllow = [
  '1.2.3.4'
]
param virtualNetworkAddressPrefix = '10.4.0.0/22'
param apiManagementPublisherEmail = 'info@microsoft.com'
param apiManagementPublisherName = 'info@microsoft.com'
param apiUrlSuffix = '/api/v1'
param logAnalyticsWorkspaceId = '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/Observability/providers/Microsoft.OperationalInsights/workspaces/contosoworkspace'
param frontDoorProfileName = 'afd-profile-contoso'
param frontDoorResourceGroupName = 'GlobalNetworking'
param frontDoorSubscriptionId = '00000000-0000-0000-0000-000000000000'
