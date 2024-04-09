@description('The name of the Environment being deployed.')
@allowed([
  'prod'
  'stage'
  'dev'
])
param environmentName string

@description('The name of the Instance where the resources will be deployed.')
param stampInstanceName string

@description('The address prefix to be allocated to the Virtual Network.')
param vNetAddressPrefix string

@description('The address prefix to be used for the  subnet.')
param subnetAddressPrefix string

@description('The Cloud Region where the resources will be deployed.')
param cloudRegion string = resourceGroup().location

@description('The tags to attach to the resources.')
param tags object

// Variables
var isProductionDeployment = contains(environmentName, 'prod')
var vNetName = 'vnet-${stampInstanceName}'

// Create the Network
module virtualNetwork 'br/public:avm/res/network/virtual-network:0.1.5' = {
  name: '${uniqueString(deployment().name)}-vnet'
  params: {
    name: vNetName
    addressPrefixes: ['${vNetAddressPrefix}']
    location: cloudRegion
    lock: (isProductionDeployment) ? {
      kind: 'CanNotDelete'
      name: 'do-not-delete'
    } : {}
    subnets: [
      {
        name: 'workload-subnet'
        addressPrefix: subnetAddressPrefix
      }
    ]
    tags: tags
  }
}

// Reference the Resources to return the output parameters
resource vnet 'Microsoft.Network/virtualNetworks@2023-09-01' existing = {
  name: vNetName
  resource workloadSubnet 'subnets@2023-09-01' existing = {
    name: 'workload-subnet'
  }
} 

// Outputs
output virtualNetworkId string = vnet.id
output virtualNetworkName string = vNetName
output subnetId string = vnet::workloadSubnet.id
output subnetName string = vnet::workloadSubnet.name
