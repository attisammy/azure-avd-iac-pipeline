// keyvault.bicep
// Creates a Key Vault that uses Azure RBAC (not access policies)
// to control who can read secrets and certificates.

@description('Azure region for the Key Vault.')
param location string

@description('Short prefix used in resource names, for example avdlab.')
param namePrefix string

@description('Days a deleted vault or secret can be recovered.')
@minValue(7)
@maxValue(90)
param softDeleteRetentionInDays int = 7

// Key Vault names must be globally unique and 3-24 characters long.
var keyVaultName = take('kv-${namePrefix}-${uniqueString(resourceGroup().id)}', 24)

resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: keyVaultName
  location: location
  properties: {
    tenantId: subscription().tenantId
    sku: {
      family: 'A'
      name: 'standard'
    }
    enableRbacAuthorization: true
    enableSoftDelete: true
    softDeleteRetentionInDays: softDeleteRetentionInDays
    publicNetworkAccess: 'Enabled'
  }
}

output keyVaultName string = keyVault.name
output keyVaultId string = keyVault.id
