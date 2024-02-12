<#
.SYNOPSIS
Creates a certificate in Azure Key Vault with the specified name, DNS name, and vault name.

.DESCRIPTION
This script creates a certificate in Azure Key Vault using the provided parameters. It performs the following steps:
1. Checks if the certificate name, DNS name, and vault name are provided.
2. Adds the public IP address of the current machine to the network rules of the specified vault.
3. Creates a certificate policy with the specified subject name, DNS name, issuer name, and validity period.
4. Adds the certificate to the specified vault with the provided name and policy.

.PARAMETER certificatename
The name of the certificate to be created.

.PARAMETER dnsname
The DNS name associated with the certificate.

.PARAMETER vaultname
The name of the Azure Key Vault where the certificate will be stored.

.EXAMPLE
.\create-cert.ps1 -certificatename "MyCertificate" -dnsname "example.com" -vaultname "MyKeyVault"

This example creates a certificate named "MyCertificate" in the Azure Key Vault named "MyKeyVault" with the DNS name "example.com".

.NOTES
- This script requires the Azure PowerShell module to be installed.
- The current machine must have the necessary permissions to access and modify the specified Azure Key Vault.
#>

[string]$certificatename = $env:certificatename
[string]$dnsname = $env:dnsname
[string]$vaultname = $env:vaultname

if ([string]::IsNullOrEmpty($certificatename) ){
    Write-Output "Certificate name is not provided"
    throw "Certificate name is not provided"
}

if ([string]::IsNullOrEmpty($dnsname)){
    Write-Output "DNS name is not provided"
    throw "DNS name is not provided"
}

if ([string]::IsNullOrEmpty($vaultname)){
    Write-Output "Vault name is not provided"
    throw "Vault name is not provided"
}

Write-Output "Creating certificate $certificatename in vault $vaultname with DNS name $dnsname"
$subjectName = "CN=$certificatename"
try {
    $ip = (curl ifconfig.me/ip)
    Add-AzKeyVaultNetworkRule -VaultName $vaultname -IpAddressRange $ip
    $Policy = New-AzKeyVaultCertificatePolicy -SecretContentType "application/x-pkcs12" -SubjectName $subjectName -dnsname $dnsname -IssuerName "Self" -ValidityInMonths 6 -ReuseKeyOnRenewal
    Add-AzKeyVaultCertificate -vaultname $vaultname -Name $certificatename -CertificatePolicy $Policy
    Write-Output "Successfully created certificate $certificatename in vault $vaultname with DNS name $dnsname"
}
catch {
    Write-Output "Failed to create certificate $certificatename in vault $vaultname with DNS name $dnsname"
    Write-Output $_.Exception.Message
    Write-Output $_.Exception
    throw $_.Exception.Message
}