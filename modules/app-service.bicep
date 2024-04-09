@description('The name of the Environment being deployed.')
@allowed([
  'prod'
  'stage'
  'dev'
])
param environmentName string

@description('The Name of the App Service that you want to deploy.')
param appServiceName string

@minValue(1)
@maxValue(30)
@description('The number of instances to be deployed per App Service Plan. If you enable Zone redundancy, a minimum of 3 instances are required.')
param minNumberOfInstancesPerAppServicePlan int

@description('The SKU of the App Service Plan instances.')
@allowed([
  'P0v3'
  'P1v3'
  'P2v3'
  'P3v3'
])
param planSku string

@description('The Resource Id of the Log Analytics Workspace where the diagnostic settings will be sent.')
param logAnalyticsWorkspaceResourceId string

@description('The Id of the Subnet where the Private Endpoint will be deployed.')
param subnetId string

@description('The Id of the Private DNS Zone.')
param keyVaultPrivateDnsZoneId string

@description('The Connection String of the Application Insights instance.')
param appInsightsConnectionString string

@description('The Name of the Key Vault where the secrets are stored.')
param keyVaultName string

@description('The Cloud Region where the resources will be deployed.')
param cloudRegion string

@description('Should Zone Redundancy be enabled for this resource.')
param enableZoneRedundancy bool

@description('The tags to attach to the resources.')
param tags object

// Variables
var isProductionDeployment = contains(environmentName, 'prod')
var appServicePlanName = 'app-svc-plan-${appServiceName}'
var appServiceSiteName = 'app-svc-site-${appServiceName}'
var keyVaultRoleId = '4633458b-17de-408a-b874-0445c86b69e6' // Key Vault Secrets User
//var keyVaultRoleId = 'b86a8fe4-44ce-4948-aee5-eccb2c155cd7' // Key Vault Secrets Officer

// The Key Vault
resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' existing = {
  name: keyVaultName
}

// The App Service Plans
module appServicePlan 'br/public:avm/res/web/serverfarm:0.1.1' = {
  name: '${uniqueString(deployment().name)}-asp'
  params: {
    name: appServicePlanName
    kind: 'Linux'
    reserved: true 
    location: cloudRegion
    perSiteScaling: true
    zoneRedundant: enableZoneRedundancy
    sku: {
      capacity: minNumberOfInstancesPerAppServicePlan
      family: 'P'
      name: planSku
      size: planSku
      tier: 'Premium'
    }
    diagnosticSettings: [
      {
        workspaceResourceId: logAnalyticsWorkspaceResourceId
      }
    ]
    lock: (isProductionDeployment)? {
      kind: 'CanNotDelete'
      name: 'do-not-delete-lock'
    } : {}
    tags: tags
  }
}

// The App Service hosting sites
module appServiceSite 'br/public:avm/res/web/site:0.3.2' = {
  name: '${uniqueString(deployment().name)}-site'
  params: {
    name: appServiceSiteName
    kind: 'app'
    httpsOnly: true
    clientAffinityEnabled: false
    location: cloudRegion
    publicNetworkAccess: 'Disabled'
    scmSiteAlsoStopped: false
    serverFarmResourceId: appServicePlan.outputs.resourceId
    basicPublishingCredentialsPolicies: [
      {
        name: 'ftp'
        allow: false
      }
      {
        name: 'scm'
        allow: false
      }
    ]
    siteConfig: {
      alwaysOn: true
      linuxFxVersion: 'DOTNETCORE|8.0'
      //linuxFxVersion: 'DOCKER|mcr.microsoft.com/appsvc/staticsite:latest'
      fttpsState: 'Disabled'
      metadata: [
        {
          name: 'CURRENT_STACK'
          value: 'dotnetcore'
        }
      ]
      appSettings: [
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: appInsightsConnectionString
        }
        {
          name: 'ApplicationInsightsAgent_EXTENSION_VERSION'
          value: '~3'
        }
        {
          name: 'XDT_MicrosoftApplicationInsights_Mode'
          value: 'Recommended'
        }
        {
          name: 'SpecialSecretFromTheVault'
          value: '@Microsoft.KeyVault(SecretUri=${keyVault.properties.vaultUri}secrets/DevelopementTestSecret/)'
        }
        {
          name: 'ApiKey'
          value: '@Microsoft.KeyVault(SecretUri=${keyVault.properties.vaultUri}secrets/ApiKey/)'
        }
        {
          name: 'ApiPassword'
          value: '@Microsoft.KeyVault(SecretUri=${keyVault.properties.vaultUri}secrets/ApiPassword/)'
        }
      ]
    }
    lock: (isProductionDeployment)? {
      kind: 'CanNotDelete'
      name: 'do-not-delete-lock'
    } : {}
    managedIdentities: {
      systemAssigned: true
    }
    privateEndpoints: [
      {
        name: 'pep-app-svc-${appServiceName}'
        privateDnsZoneResourceIds: [
          keyVaultPrivateDnsZoneId
        ]
        subnetResourceId: subnetId
        tags: tags
      }
    ]
    diagnosticSettings: [
      {
        metricCategories: [
          {
            category: 'AllMetrics'
          }
        ]
        name: 'all-metrics'
        workspaceResourceId: logAnalyticsWorkspaceResourceId
      }
    ]
    tags: tags
  }
  dependsOn: [
    appServicePlan
  ]
}

resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid('${appServiceName}-${environmentName}-kv-role-assignment')
  scope: keyVault
  properties: {
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', keyVaultRoleId)
    principalId: appServiceSite.outputs.systemAssignedMIPrincipalId
    principalType: 'ServicePrincipal'
  }
}

// Outputs
output appServiceFqdn string = appServiceSite.outputs.defaultHostname
output appServiceSiteName string = appServiceSite.outputs.name
output appServicePlanName string = appServicePlan.outputs.name
output appServicePlanLocation string = appServicePlan.outputs.location
output appServicePlanResourceId string = appServicePlan.outputs.resourceId
