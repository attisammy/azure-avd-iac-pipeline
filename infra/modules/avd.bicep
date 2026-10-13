// avd.bicep
// Creates the AVD control plane objects: a pooled host pool,
// a desktop application group and a workspace. The host pool's
// registration token is stored in Key Vault, never output.

@description('Azure region for the AVD objects. Must be an AVD-supported region.')
param location string

@description('Short prefix used in resource names, for example avdlab.')
param namePrefix string

@description('Name of the existing Key Vault that will hold the registration token.')
param keyVaultName string

@description('Maximum users sharing one session host at the same time.')
@minValue(1)
@maxValue(20)
param maxSessionLimit int = 4

@description('Hours until the registration token expires.')
@minValue(1)
@maxValue(24)
param tokenValidityHours int = 8

@description('Deployment time. Leave as default; used to calculate the token expiry.')
param baseTime string = utcNow('u')

var tokenExpiration = dateTimeAdd(baseTime, 'PT${tokenValidityHours}H')

resource hostPool 'Microsoft.DesktopVirtualization/hostPools@2024-04-03' = {
  name: 'hp-${namePrefix}'
  location: location
  properties: {
    friendlyName: 'AVD Lab Host Pool'
    hostPoolType: 'Pooled'
    loadBalancerType: 'BreadthFirst'
    maxSessionLimit: maxSessionLimit
    preferredAppGroupType: 'Desktop'
    validationEnvironment: false
    startVMOnConnect: false
    customRdpProperty: 'drivestoredirect:s:;redirectclipboard:i:0;redirectprinters:i:0;'
    registrationInfo: {
      expirationTime: tokenExpiration
      registrationTokenOperation: 'Update'
    }
  }
}

resource appGroup 'Microsoft.DesktopVirtualization/applicationGroups@2024-04-03' = {
  name: 'dag-${namePrefix}'
  location: location
  properties: {
    friendlyName: 'AVD Lab Desktop'
    applicationGroupType: 'Desktop'
    hostPoolArmPath: hostPool.id
  }
}

resource workspace 'Microsoft.DesktopVirtualization/workspaces@2024-04-03' = {
  name: 'ws-${namePrefix}'
  location: location
  properties: {
    friendlyName: 'CloudOps Academy Lab'
    applicationGroupReferences: [
      appGroup.id
    ]
  }
}

resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' existing = {
  name: keyVaultName
}

resource tokenSecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'avd-registration-token'
  properties: {
    value: hostPool.listRegistrationTokens().value[0].token
    contentType: 'AVD host pool registration token'
    attributes: {
      exp: dateTimeToEpoch(tokenExpiration)
    }
  }
}

output hostPoolName string = hostPool.name
output appGroupId string = appGroup.id
output workspaceName string = workspace.name
