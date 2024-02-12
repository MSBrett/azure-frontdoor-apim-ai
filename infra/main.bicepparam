
using './main.bicep'

param workloadName = 'contoso-aoai'
param location = 'eastus'
param tags = {
  deploymentName: 'contoso'
  environmentType: 'development'
}
param virtualNetworkAddressPrefix = '10.4.0.0/22'
param apiManagementPublisherEmail = 'info@contoso.com'
param apiManagementPublisherName = 'info@contoso.com'
param logAnalyticsWorkspaceId = '/subscriptions/<id>/resourceGroups/<name>/providers/Microsoft.OperationalInsights/workspaces/<name>'
