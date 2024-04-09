@description('The name of the Environment being deployed.')
@allowed([
  'prod'
  'stage'
  'dev'
])
param environmentName string

@description('The Virtual Network to be peered with the private DNS Zone')
param virtualNetworkId string

@description('The tags to attach to the resources.')
param tags object

// Variables
var isProductionDeployment = contains(environmentName, 'prod')

// Keyvault Private DNS Zone
module keyvaultPrivateDnsZone 'br/public:avm/res/network/private-dns-zone:0.2.3' = {
  name: '${uniqueString(deployment().name)}-keyvault-pdnsz'
  params: {
    name: 'privatelink.vaultcore.azure.net'
    location: 'global'
    virtualNetworkLinks: [
      {
        registrationEnabled: false
        virtualNetworkResourceId: virtualNetworkId
      }
    ]
    lock: (isProductionDeployment) ? {
      kind: 'CanNotDelete'
      name: 'do-not-delete'
    } : {}
    tags: tags
  }
}

// App Service Private DNS Zone
module appServicePrivateDnsZone 'br/public:avm/res/network/private-dns-zone:0.2.3' = {
  name: '${uniqueString(deployment().name)}-app-service-pdnsz'
  params: {
    name: 'privatelink.azurewebsites.net'
    location: 'global'
    virtualNetworkLinks: [
      {
        registrationEnabled: false
        virtualNetworkResourceId: virtualNetworkId
      }
    ]
    lock: (isProductionDeployment) ? {
      kind: 'CanNotDelete'
      name: 'do-not-delete'
    } : {}
    tags: tags
  }
}

// Outputs
output keyvaultPrivateDnsZoneId string = keyvaultPrivateDnsZone.outputs.resourceId
output appServicePrivateDnsZoneId string = appServicePrivateDnsZone.outputs.resourceId
