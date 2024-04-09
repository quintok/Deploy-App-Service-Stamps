@description('The Id of the Virtual Network that the Private DNS Zones should be linked to')
param virtualNetworkId string

@description('The name of the Virtual Network that the Private DNS Zones should be linked to')
param virtualNetworkName string

// Variables
var privateDnsZoneVnetLinkName = 'link-to-${virtualNetworkName}'
var keyVaultLinkName = '${privateDnsZoneVnetLinkName}-vaultcore'
var appServiceLinkName = '${privateDnsZoneVnetLinkName}-azurewebsites'

// Keyvault Attach
resource keyVaultPrivateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' existing = {
  name: 'privatelink.vaultcore.azure.net'
}

resource keyVaultNetworkLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  name: keyVaultLinkName
  parent: keyVaultPrivateDnsZone
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: virtualNetworkId
    }
  }
}

// App Service Attach
resource appServicePrivateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' existing = {
  name: 'privatelink.azurewebsites.net'
}

resource appServiceNetworkLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  name: appServiceLinkName
  parent: appServicePrivateDnsZone
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: virtualNetworkId
    }
  }
}
