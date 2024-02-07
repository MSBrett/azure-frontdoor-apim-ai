@description('The name of the certificate to create in the key vault.')
param certificatename string

@description('The DNS name of the certificate to create in the key vault. This is the name that will be used to access the certificate.')
param dnsname string

@description('The name of the key vault')
param vaultname string

@description('The location of the key vault and the identity')
param location string

param identityResourceId string

resource deploymentScript 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  name: 'CreateCertificate'
  kind: 'AzurePowerShell'
  // chinaeast2 is the only region in China that supports deployment scripts
  location: startsWith(location, 'china') ? 'chinaeast2' : location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${identityResourceId}': {}
    }
  }
  properties: {
    azPowerShellVersion: '8.0'
    retentionInterval: 'PT1H'
    environmentVariables: [
      {
        name: 'certificatename'
        value: certificatename
      }
      {
        name: 'dnsname'
        value: dnsname
      }
      {
        name: 'vaultname'
        value: vaultname
      }
    ]
    scriptContent: loadTextContent('./scripts/create-cert.ps1')
  }
}

output certificateName string = certificatename
output dnsname string = dnsname
