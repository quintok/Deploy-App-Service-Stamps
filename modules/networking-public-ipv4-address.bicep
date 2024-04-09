@description('The name of the Public IPV4 Address being deployed.')
param publicIpAddressName string

@description('The Cloud Region for the deployment of core services and meta data.')
param cloudRegion string

@description('Indicates whether to deploy the resources in a zone redundant configuration.')
param deployZoneRedundantResources bool

@description('The tags to attach to the resources.')
param tags object

resource publicIPAddress 'Microsoft.Network/publicIPAddresses@2021-05-01' = {
  name: publicIpAddressName
  location: cloudRegion
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAddressVersion: 'IPv4'
    publicIPAllocationMethod: 'Static'
  }
  zones: (deployZoneRedundantResources) ? [
    '1'
    '2'
    '3'
  ] : []
  tags: tags
}

// Outputs
output publicIPAddressId string = publicIPAddress.id
output publicIPAddressName string = publicIPAddress.name
output ipv4Address string = publicIPAddress.properties.ipAddress
