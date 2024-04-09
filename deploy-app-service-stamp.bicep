targetScope='subscription'

@maxLength(10)
@description('The name of the application being deployed.')
param applicationName string

@description('The name of the Environment being deployed.')
@allowed([
  'prod'
  'stage'
  'dev'
])
param environmentName string

@description('The Cloud Region for the deployment.')
param cloudRegion string

@description('The Resource Group Name of the Hub.')
param hubResourceGroupName string

@description('The Id of the Hub Virtual Network that is used in the Hub.')
param hubVirtualNetworkId string

@description('The Name of the Hub Virtual Network that is used in the Hub.')
param hubVirtualNetworkName string

@description('The name of the application stamp.')
param stampNumber int

@description(' The App Service Plan to be used')
param appServicePlan string

@description('The number of App Service Plans to be created')
param numberOfAppServicePlans int

@description('The number of instances to be deployed per App Service Plan. If you enable Zone redundancy, a minimum of 3 instances are required.')
param minNumberOfInstancesPerAppServicePlan int

@description('The name of the Resource Group where the dependencies are deployed. This is initially used for SSL Certificates and default secrets.')
param dependenciesResourceGroupName string

@description('The name of the Key Vault where the dependencies are stored.')
param dependenciesKeyVaultName string

@description('The Resource Id of the Log Analytics Workspace where the diagnostic settings will be sent.')
param logAnalyticsWorkspaceResourceId string

@description('The Connection String of the Application Insights instance.')
param appInsightsConnectionString string

@description('The address prefix to be allocated to the Virtual Network.')
param vNetAddressPrefix string

@description('The address prefix to be used for the subnet.')
param subnetAddressPrefix string

@description('The Resource Id of the Private DNS Zone for the KeyVault.')
param keyvaultPrivateDnsZoneId string

@description('Should Zone Redundancy be enabled for this resource.')
param enableZoneRedundancy bool

@description('The tags to be applied to the resources.')
param tags object = {
  Application: applicationName
  Environment: environmentName
  Deployment: toLower('${applicationName}-${environmentName}-${cloudRegion}-stamp-${stampNumber}')
  Deployed: utcNow('dd-MM-yyyy')
}

// Variables
var instanceName = toLower('${applicationName}-${environmentName}-${cloudRegion}-stamp-${stampNumber}')
var stampResourceGroupName = '${instanceName}-rg'

// Create the Resource Groups
resource stampResourceGroup 'Microsoft.Resources/resourceGroups@2022-09-01' = {
  name: stampResourceGroupName
  location: cloudRegion
  tags: tags
}

// Create the vNET
module stampVirtualNetwork 'modules/networking-create-virtual-network.bicep' = {
  name: '${uniqueString(deployment().name)}-vnet-${environmentName}'
  scope: stampResourceGroup
  params: {
    stampInstanceName: instanceName
    cloudRegion: cloudRegion
    environmentName: environmentName
    vNetAddressPrefix: vNetAddressPrefix
    subnetAddressPrefix: subnetAddressPrefix
    tags: tags
  }
}

// Peer the Hub VNET with the Stamp
module peerStampToHubVirtualNetwork 'modules/networking-peer-vnet-to-hub.bicep' = {
  name: '${uniqueString(deployment().name)}-vnet-peer-hub-${environmentName}'
  scope: stampResourceGroup
  params: {
    peeringConnectionName: 'peer-${instanceName}-to-hub'
    sourceVirtualNetworkName: 'vnet-${instanceName}'
    targetVirtualNetorkId: hubVirtualNetworkId
  }
  dependsOn: [
    stampVirtualNetwork
  ]
}

// Peer the Stamp VNET with the Hub
module peerHubToStampVirtualNetwork 'modules/networking-peer-vnet-to-hub.bicep' = {
  name: '${uniqueString(deployment().name)}-vnet-peer-stamp-${environmentName}'
  scope: resourceGroup(hubResourceGroupName)
  params: {
    peeringConnectionName: 'peer-hub-to-${instanceName}'
    sourceVirtualNetworkName: hubVirtualNetworkName
    targetVirtualNetorkId: stampVirtualNetwork.outputs.virtualNetworkId
  }
  dependsOn: [
    stampVirtualNetwork
  ]
}

// Attach the Private DNS Zones
module attachPrivateDnsZones 'modules/networking-attach-private-dns-zones.bicep' = {
  name: '${uniqueString(deployment().name)}-attach-private-dns-zones-${environmentName}'
  scope: resourceGroup(hubResourceGroupName)
  params: {
    virtualNetworkId: stampVirtualNetwork.outputs.virtualNetworkId
    virtualNetworkName: stampVirtualNetwork.outputs.virtualNetworkName
  }
  dependsOn: [
    stampVirtualNetwork
  ]
}

// Deploy the KeyVault
module keyvault 'modules/keyvault.bicep' = {
  name: '${uniqueString(deployment().name)}-kv-${environmentName}'
  scope: stampResourceGroup
  params: {
    environmentName: environmentName
    cloudRegion: cloudRegion
    logAnalyticsWorkspaceResourceId: logAnalyticsWorkspaceResourceId
    keyVaultPrivateDnsZoneId: keyvaultPrivateDnsZoneId
    subnetId: stampVirtualNetwork.outputs.subnetId
    tags: tags
  }
}

// Deploy the App Service Stamps
module appService 'modules/app-service.bicep' = [for i in range(1, numberOfAppServicePlans) : {
  name: '${uniqueString(deployment().name)}-${i}-asp-${environmentName}'
  scope: stampResourceGroup
  params: {
    appServiceName: '${instanceName}-instance-${i}'
    environmentName: environmentName
    cloudRegion: cloudRegion
    keyVaultName: keyvault.outputs.keyVaultName
    subnetId: stampVirtualNetwork.outputs.subnetId
    keyVaultPrivateDnsZoneId: keyvaultPrivateDnsZoneId
    logAnalyticsWorkspaceResourceId: logAnalyticsWorkspaceResourceId
    minNumberOfInstancesPerAppServicePlan: minNumberOfInstancesPerAppServicePlan
    planSku: appServicePlan
    appInsightsConnectionString: appInsightsConnectionString
    enableZoneRedundancy: enableZoneRedundancy
    tags: tags
  }
  dependsOn: [
    stampVirtualNetwork
    keyvault
  ]
}]

// Seed Key Vault Secrets
module seeKeyVaultValues 'modules/keyvault-seed-initial-secrets.bicep' = {
  name: '${uniqueString(deployment().name)}-seed-kv-${environmentName}'
  scope: stampResourceGroup
  params: {
    keyNames: ['ApiKey', 'ApiPassword']
    targetKeyVaultName: keyvault.outputs.keyVaultName
    targetResourceGroupName: stampResourceGroupName
    dependenciesResourceGroupName: dependenciesResourceGroupName
    dependenciesKeyVaultName: dependenciesKeyVaultName
  }
  dependsOn: [
    keyvault
    appService
  ]
}

// Outputs
output stampResourceGroupName string = stampResourceGroup.name
output stampVirtualNetworkId string = stampVirtualNetwork.outputs.virtualNetworkId
output stampVirtualNetworkName string = stampVirtualNetwork.outputs.virtualNetworkName
output keyVaultName string = keyvault.outputs.keyVaultName
output appServicePlanName string = appServicePlan

output backendAddressPool array = [for i in range(0, numberOfAppServicePlans) : {
  fqdn: appService[i].outputs.appServiceFqdn
}]
