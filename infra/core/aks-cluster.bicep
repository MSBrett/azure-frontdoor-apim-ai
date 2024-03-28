param clusterName string
param logworkspaceid string
param aadGroupdIds array
param vnetName string
param subnetId string
param kubernetesVersion string
param location string
param infraResourceGroupName string
param nodeResourceGroupName string
param availabilityZones array = []
param enableAutoScaling bool = false
param autoScalingProfile object = {
  'balance-similar-node-groups': 'false'
  expander: 'random'
  'max-empty-bulk-delete': '10'
  'max-graceful-termination-sec': '600'
  'max-node-provision-time': '15m'
  'max-total-unready-percentage': '45'
  'new-pod-scale-up-delay': '0s'
  'ok-total-unready-count': '3'
  'scale-down-delay-after-add': '10m'
  'scale-down-delay-after-delete': '10s'
  'scale-down-delay-after-failure': '3m'
  'scale-down-unneeded-time': '10m'
  'scale-down-unready-time': '20m'
  'scale-down-utilization-threshold': '0.5'
  'scan-interval': '10s'
  'skip-nodes-with-local-storage': 'false'
  'skip-nodes-with-system-pods': 'true'
}
param enableDefenderForAKSPolicySetDefinitionId string = '/providers/Microsoft.Authorization/policyDefinitions/64def556-fbad-4622-930e-72d1d5589bf5'
param defaultPoolVmSize string = 'Standard_D2s_v5'
param gpuPoolVmSize string = 'Standard_NC24ads_A100_v4'
@allowed([
  'Regular'
  'Spot'
])
param gpuScaleSetPriority string = 'Regular'
param adminUsername string = 'azaksadmin'
param sshKeyData string = ''

var privateDNSZoneAKSSuffixes = {
  AzureCloud: '.azmk8s.io'
  AzureUSGovernment: '.cx.aks.containerservice.azure.us'
  AzureChinaCloud: '.cx.prod.service.azk8s.cn'
  AzureGermanCloud: '' //TODO: what is the correct value here?
}

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2023-04-01' existing = {
  name: vnetName
}

resource infraResourceGroup 'Microsoft.Resources/resourceGroups@2022-09-01'existing = {
  name: infraResourceGroupName
  scope: subscription()
}

resource identity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: '${clusterName}-mi'
  location: location
}

module rg_aksPvtNetworkContrib 'role.bicep' = {
  name: 'rg_aksPvtNetworkContrib'
  scope: infraResourceGroup
  params: {
    principalId: identity.properties.principalId
    roleGuid: '4d97b98b-1d4f-4787-a291-c67834d212e7'
    resourceGroupName: infraResourceGroup.name
  }
}

module rg_aksPvtDNSContrib 'role.bicep' = {
  name: 'rg_aksPvtDNSContrib'
  scope: infraResourceGroup
  params: {
    principalId: identity.properties.principalId
    roleGuid: 'b12aa53e-6015-4669-85d0-8515ebb3ae7f'
    resourceGroupName: infraResourceGroup.name
  }
}

module rg_aksPodIdentityRole 'role.bicep' = {
  name: 'rg_aksPodIdentityRole'
  scope: infraResourceGroup
  params: {
    principalId: identity.properties.principalId
    roleGuid: 'f1a07417-d97a-45cb-824c-7a7467783830'
    resourceGroupName: infraResourceGroup.name
  }
}

resource DefAKSAssignment 'Microsoft.Authorization/policyAssignments@2022-06-01' = if (environment().name == 'AzureCloud') {
  name: 'EnableDefenderForAKS'
  location: location
  properties: {
    policyDefinitionId: enableDefenderForAKSPolicySetDefinitionId
  }
  identity: {
    type: 'SystemAssigned'
  }
}

resource privateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'privatelink.${toLower(location)}${privateDNSZoneAKSSuffixes[environment().name]}'
  location: 'global'
  properties: {}
}

resource privateDnsZoneLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' =  {
  parent: privateDnsZone
  name: '${privateDnsZone.name}-link'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: virtualNetwork.id
    }
  }
}

resource aksCluster 'Microsoft.ContainerService/managedClusters@2024-01-01' = {
  name: clusterName
  location: location
  dependsOn: [    
    rg_aksPvtNetworkContrib
    rg_aksPvtDNSContrib
    rg_aksPodIdentityRole
    DefAKSAssignment
    privateDnsZoneLink
  ]
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${identity.id}': {}
    }
  }
  sku: {
    name: 'Base'
    tier: 'Standard'
  }
  properties: {
    kubernetesVersion: kubernetesVersion
    nodeResourceGroup: nodeResourceGroupName
    dnsPrefix: clusterName
    publicNetworkAccess: 'Disabled'
    agentPoolProfiles: [
      {
        enableAutoScaling: true
        name: 'defaultpool'
        availabilityZones: !empty(availabilityZones) ? availabilityZones : null
        mode: 'System'
        count: 1
        minCount: 1
        maxCount: 3
        vmSize: defaultPoolVmSize
        osType: 'Linux'
        osDiskSizeGB: 30
        type: 'VirtualMachineScaleSets'
        vnetSubnetID: subnetId
      }
    ]
    networkProfile: {
      networkPlugin: 'azure'
      loadBalancerSku: 'Standard'
      //outboundType: 'loadBalancer'
      dnsServiceIP: '192.168.100.10'
      serviceCidr: '192.168.100.0/24'
      //networkPolicy: 'azure'
    }
    apiServerAccessProfile: {
      enablePrivateCluster: true
      privateDNSZone: privateDnsZone.id
      enablePrivateClusterPublicFQDN: false
    }
    enableRBAC: true
    aadProfile: {
      adminGroupObjectIDs: aadGroupdIds
      enableAzureRBAC: true
      managed: true
      tenantID: subscription().tenantId
    }
    addonProfiles: {
      omsagent: {
        config: {
          logAnalyticsWorkspaceResourceID: logworkspaceid
        }
        enabled: true
      }
      azurepolicy: {
        enabled: true
      }
      azureKeyvaultSecretsProvider: {
        enabled: true
      }
    }
  }
}

resource gpupool 'Microsoft.ContainerService/managedClusters/agentPools@2024-01-01' = {
  parent: aksCluster
  name: 'gpupool'
  properties: {
    enableAutoScaling: false
    availabilityZones: !empty(availabilityZones) ? availabilityZones : null
    mode: 'User'
    nodeLabels: {
      'gpu-node': 'true'
    }
    count: 2
    vmSize: gpuPoolVmSize
    osType: 'Linux'
    osDiskSizeGB: 30
    type: 'VirtualMachineScaleSets'
    vnetSubnetID: subnetId
    scaleSetPriority: gpuScaleSetPriority
  }
}

output kubeletIdentity string = aksCluster.properties.identityProfile.kubeletidentity.objectId
output keyvaultaddonIdentity string = aksCluster.properties.addonProfiles.azureKeyvaultSecretsProvider.identity.objectId
output nodeResourceGroup string = aksCluster.properties.nodeResourceGroup
output clusterName string = aksCluster.name
