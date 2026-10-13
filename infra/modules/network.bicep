// network.bicep
// Creates a virtual network with one subnet for AVD session hosts,
// protected by a network security group (NSG).

@description('Azure region for all network resources.')
param location string

@description('Short prefix used in resource names, for example avdlab.')
param namePrefix string

@description('Address space for the virtual network.')
param vnetAddressPrefix string = '10.0.0.0/20'

@description('Address range for the session host subnet.')
param subnetAddressPrefix string = '10.0.0.0/24'

resource nsg 'Microsoft.Network/networkSecurityGroups@2024-05-01' = {
  name: 'nsg-${namePrefix}-hosts'
  location: location
  properties: {
    securityRules: []
  }
}

resource vnet 'Microsoft.Network/virtualNetworks@2024-05-01' = {
  name: 'vnet-${namePrefix}'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetAddressPrefix
      ]
    }
    subnets: [
      {
        name: 'snet-avd-hosts'
        properties: {
          addressPrefix: subnetAddressPrefix
          networkSecurityGroup: {
            id: nsg.id
          }
        }
      }
    ]
  }
}

output vnetId string = vnet.id
output subnetId string = vnet.properties.subnets[0].id
