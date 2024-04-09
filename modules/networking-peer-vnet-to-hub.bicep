@description('The name of the Virtual Network that the Private DNS Zones should be linked to')
param sourceVirtualNetworkName string

@description('The Hub Virtual Network Id that the Virtual Network should be peered to')
param targetVirtualNetorkId string

@maxLength(80)
@description('The name of the Peering Connection')
param peeringConnectionName string

// Virtual Network
resource sourceVirtualNetwork 'Microsoft.Network/virtualNetworks@2023-09-01' existing = {
  name: sourceVirtualNetworkName
} 

// Create the Peering Connection
resource hubToStampVnetPeer 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2020-06-01' = {
  name: peeringConnectionName
  parent: sourceVirtualNetwork
  properties: {
    allowForwardedTraffic: false
    allowGatewayTransit: false
    allowVirtualNetworkAccess: true
    useRemoteGateways: false
    remoteVirtualNetwork: {
      id: targetVirtualNetorkId
    }
  }
}
