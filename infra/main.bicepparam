using './main.bicep'

param apiManagementPublisherEmail = 'info@contoso.com'
param apiManagementPublisherName = 'info@contoso.com'
param aadGroupdIds = [
  '00000000-0000-0000-0000-000000000000'
]
param apiPathSuffix = '/api/v1'
param dnsZoneName = 'ai.contoso.com'
param frontDoorProfileName = 'afd-contoso'
param frontDoorResourceGroupName = 'GlobalNetworking'
param frontDoorSubscriptionId = '00000000-0000-0000-0000-000000000000'
param ipAddressRangesToAllow = [
  '1.2.3.4'
]
param location = 'eastus'
param location_aks = 'westus3'
param logAnalyticsWorkspaceId = '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/Observability/providers/Microsoft.OperationalInsights/workspaces/contosoworkspace'
param tags = {
  application: 'ai'
  customer: 'fabrikam'
  environment: 'development'
}
param virtualNetworkAddressPrefix = '10.4.0.0/22'
param workloadName = 'fabrikam'
param gpuScaleSetPriority = 'Spot'
