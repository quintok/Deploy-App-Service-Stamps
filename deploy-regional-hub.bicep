@description('The name of the Environment being deployed.')
@allowed([
  'prod'
  'stage'
  'dev'
])
param environmentName string

@maxLength(10)
@description('The name of the application being deployed.')
param applicationName string

@description('The address prefix to be allocated to the Virtual Network.')
param vNetAddressPrefix string

@description('The address prefix to be used for the  subnet.')
param subnetAddressPrefix string

@description('The Cloud Region for the deployment of core services and meta data.')
param cloudRegion string

@description('The tags to be applied to the resources.')
param tags object = {
  Application: applicationName
  Environment: environmentName
  Deployment: toLower('${applicationName}-${environmentName}-${cloudRegion}')
  Deployed: utcNow('dd-MM-yyyy')
}

// Variables
var isProductionDeployment = contains(environmentName, 'prod')
var applicationAndEnvironmentName = toLower(replace('${applicationName}-${environmentName}', ' ', '-'))
var hubVNetName = 'vnet-hub-${applicationAndEnvironmentName}-${cloudRegion}'
var hubSubnetName = 'hub-subnet'

// Create the Log Analytics Workspace and Application Insights for the Application
module telemetry 'modules/telemetry.bicep' = {
  name: '${uniqueString(deployment().name)}-telemetry-${environmentName}'
  params: {
    applicationName: applicationName
    environmentName: environmentName
    cloudRegion: cloudRegion
    dailyQuotaGb: 5
    dataRetentionInDays: 30
    tags: tags
  }
}

// Create the Hub Network
module virtualNetwork 'br/public:avm/res/network/virtual-network:0.1.5' = {
  name: '${uniqueString(deployment().name)}-vnet-${environmentName}'
  params: {
    name: hubVNetName
    addressPrefixes: ['${vNetAddressPrefix}']
    location: cloudRegion
    lock: (isProductionDeployment)? {
      kind: 'CanNotDelete'
      name: 'do-not-delete-lock'
    } : {}
    subnets: [
      {
        name: hubSubnetName
        addressPrefix: subnetAddressPrefix
      }
    ]
    tags: tags
  }
}

// Create the Private DNS Zones
module privateDnsZone 'modules/networking-create-private-dns-zones.bicep' = {
  name: '${uniqueString(deployment().name)}-pdnsz-${environmentName}'
  params: {
    environmentName: environmentName
    virtualNetworkId: virtualNetwork.outputs.resourceId
    tags: tags
  }
}

// Reference the Resources to return the output parameters
resource vnet 'Microsoft.Network/virtualNetworks@2023-09-01' existing = {
  name: '${applicationAndEnvironmentName}-${cloudRegion}-hub-vnet'

  resource subnet 'subnets@2023-09-01' existing = {
    name: 'hub-subnet'
  }
}

// Outputs
output hubVirtualNetworkId string = virtualNetwork.outputs.resourceId
output hubVirtualNetworkName string = virtualNetwork.outputs.name
output subnetId string = vnet::subnet.id
output subnetName string = vnet::subnet.name
output appInsightsConnectionString string = telemetry.outputs.appInsightsConnectionString
output logAnalyticsWorkspaceResourceId string = telemetry.outputs.logAnalyticsWorkspaceResourceId
output keyvaultPrivateDnsZoneId string = privateDnsZone.outputs.keyvaultPrivateDnsZoneId
