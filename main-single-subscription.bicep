targetScope = 'subscription'

metadata name = 'Deployment of the App Services Landing Zone example.'
metadata description = 'This module will deploy the application landing zones for in the application in the defined region.'

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

@description('The Http Host Name for the Application Gateway.')
param applicationHostName string

@description('The name of the Resource Group where the dependencies are deployed. This is initially used for SSL Certificates and default secrets.')
param dependenciesResourceGroupName string

@description('The name of the Key Vault where the dependencies are stored.')
param dependenciesKeyVaultName string

@description('The Name of the SSL Certificate to attach to the Application Gateway.')
param sslCertificateName string

@description('The number of App Service Stamps to deploy for the application. Each stam includes one or more App Service Plans.')
param numberOfStamps int

@description('The number of App Service Plans to deploy for each Stamp.')
param numberOfAppServicePlansPerStamp int

@description('The number of instances to be deployed per App Service Plan. If you enable Zone redundancy, a minimum of 3 instances are required.')
param minNumberOfInstancesPerAppServicePlan int

@description('The SKU of the App Service Plan instances.')
@allowed([
  'P0v3'
  'P1v3'
  'P2v3'
  'P3v3'
])
param appServicePlanSku string

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
var applicationAndEnvironmentName = toLower(replace('${applicationName}-${environmentName}', ' ', '-'))

// Create the Hub Resource Group
resource hubResourceGroup 'Microsoft.Resources/resourceGroups@2022-09-01' = {
  name: '${applicationAndEnvironmentName}-${cloudRegion}-core-rg'
  location: cloudRegion
  tags: tags
}

// Deploy the Regional Hub
// This includes the Virtual Network, Subnet, Key Vault, App Insights, Log Analytics, and Private DNS Zone.
// The App Gateway is deployed once we have all the App Services host names to add to the backend pool.
module hubDeployment 'deploy-regional-hub.bicep' = {
  name: '${uniqueString(deployment().name)}-hub'
  scope: hubResourceGroup
  params: {
    applicationName: applicationName
    environmentName: environmentName
    vNetAddressPrefix: '172.16.100.0/24'
    subnetAddressPrefix: '172.16.100.0/24'
    cloudRegion: cloudRegion
  }
}

// Deploy the App Service Stamps
// Each Stamp can include one or more App Service Plans.
module AppServiceStamps 'deploy-app-service-stamp.bicep' = [
  for i in range(0, numberOfStamps): {
    name: '${uniqueString(deployment().name)}-${cloudRegion}-stamp-${i+1}-${environmentName}'
    dependsOn: [
      hubDeployment
    ]
    params: {
      environmentName: environmentName
      applicationName: applicationName
      dependenciesKeyVaultName: dependenciesKeyVaultName
      dependenciesResourceGroupName: dependenciesResourceGroupName
      stampNumber: i + 1
      appServicePlan: appServicePlanSku
      numberOfAppServicePlans: numberOfAppServicePlansPerStamp
      minNumberOfInstancesPerAppServicePlan: minNumberOfInstancesPerAppServicePlan
      hubResourceGroupName: hubResourceGroup.name
      hubVirtualNetworkId: hubDeployment.outputs.hubVirtualNetworkId
      hubVirtualNetworkName: hubDeployment.outputs.hubVirtualNetworkName
      keyvaultPrivateDnsZoneId: hubDeployment.outputs.keyvaultPrivateDnsZoneId
      appInsightsConnectionString: hubDeployment.outputs.appInsightsConnectionString
      logAnalyticsWorkspaceResourceId: hubDeployment.outputs.logAnalyticsWorkspaceResourceId
      vNetAddressPrefix: '192.168.${i}.0/24'
      subnetAddressPrefix: '192.168.${i}.0/24'
      enableZoneRedundancy: true
      cloudRegion: cloudRegion
    }
  }
]

// Deploy the App Gateway and link the App Service Instances to the backend pool
module appGateway 'modules/app-gateway.bicep' = {
  name: '${uniqueString(deployment().name)}-app-gateway-${environmentName}'
  scope: hubResourceGroup
  params: {
    environmentName: environmentName
    applicationName: applicationName
    applicationHostName: applicationHostName
    virtualNetworkName: hubDeployment.outputs.hubVirtualNetworkName
    subnetName: hubDeployment.outputs.subnetName
    sslCertificateName: sslCertificateName
    dependenciesResourceGroupName: dependenciesResourceGroupName
    dependenciesKeyVaultName: dependenciesKeyVaultName
    deployZoneRedundantResources: true
    logAnalyticsWorkspaceResourceId: hubDeployment.outputs.logAnalyticsWorkspaceResourceId
    cloudRegion: cloudRegion
    backendAddressPools: [for stamp in range(0, numberOfStamps): AppServiceStamps[stamp].outputs.backendAddressPool]
    tags: {
      Application: applicationName
      Environment: environmentName
      Deployment: toLower('${applicationName}-${environmentName}-${cloudRegion}')
    }
  }
  dependsOn: [
    AppServiceStamps
  ]
}

// Create the Budget
var resourceGroups = [for i in range(1, numberOfStamps): '${applicationAndEnvironmentName}-${cloudRegion}-stamp-${i}']
module budgets 'modules/budget.bicep' = {
  name: '${uniqueString(deployment().name)}-budgets'
  params: {
    budgetName: '${applicationAndEnvironmentName}-${cloudRegion}-budget'
    resourceGroups: union(resourceGroups, [hubResourceGroup.name])
    alertEmailAddresses: ['xxx@gmail.com']
    budgetValue: 10
    cloudRegion: cloudRegion
  }
  dependsOn: [
    hubDeployment
    AppServiceStamps
  ]
}
