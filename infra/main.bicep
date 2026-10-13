// main.bicep
// Entry point for the AVD lab. Deploys the network, Key Vault and
// AVD control plane into an existing resource group (rg-avdlab).

targetScope = 'resourceGroup'

@description('Azure region for all resources. Defaults to the resource group region.')
param location string = resourceGroup().location

@description('Short prefix used in every resource name.')
@minLength(3)
@maxLength(10)
param namePrefix string = 'avdlab'

module network 'modules/network.bicep' = {
  name: 'network-deploy'
  params: {
    location: location
    namePrefix: namePrefix
  }
}

module keyVault 'modules/keyvault.bicep' = {
  name: 'keyvault-deploy'
  params: {
    location: location
    namePrefix: namePrefix
  }
}

module avd 'modules/avd.bicep' = {
  name: 'avd-deploy'
  params: {
    location: location
    namePrefix: namePrefix
    keyVaultName: keyVault.outputs.keyVaultName
  }
}

output subnetId string = network.outputs.subnetId
output keyVaultName string = keyVault.outputs.keyVaultName
output hostPoolName string = avd.outputs.hostPoolName
output workspaceName string = avd.outputs.workspaceName
