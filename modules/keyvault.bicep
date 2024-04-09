@description('The name of the Environment being deployed.')
@allowed([
  'prod'
  'stage'
  'dev'
])
param environmentName string

@description('The Id of the Private DNS Zone.')
param keyVaultPrivateDnsZoneId string

@description('The Id of the Subnet where the Private Endpoint will be deployed.')
param subnetId string

@description('The Resource Id of the Log Analytics Workspace where the diagnostic settings will be sent.')
param logAnalyticsWorkspaceResourceId string

@description('The Cloud Region where the resources will be deployed.')
param cloudRegion string = resourceGroup().location

@description('The tags to attach to the resources.')
param tags object

// variables
var isProductionDeployment = contains(environmentName, 'prod')
var enablePurgeProtection = isProductionDeployment
var enableSoftDelete = isProductionDeployment
var softDeleteRetentionInDays = isProductionDeployment ? 30 : 7
var vaultName = 'kv-${environmentName}-${uniqueString(resourceGroup().name)}'
var vaultSku = 'standard'
var publicNetworkAccess = 'Disabled'

// Create the Key Vault
module vault 'br/public:avm/res/key-vault/vault:0.4.0' = {
  name: '${uniqueString(deployment().name)}-kv'
  params: {
    name: vaultName
    location: cloudRegion
    sku: vaultSku
    publicNetworkAccess: publicNetworkAccess
    enableSoftDelete: enableSoftDelete
    softDeleteRetentionInDays: softDeleteRetentionInDays
    enableRbacAuthorization: true
    enablePurgeProtection: enablePurgeProtection
    lock: (isProductionDeployment)? {
      kind: 'CanNotDelete'
      name: 'do-not-delete-lock'
    } : {}
    privateEndpoints: [
      {
        name: 'pep-kv-${environmentName}-${uniqueString(resourceGroup().name)}'
        privateDnsZoneResourceIds: [
          keyVaultPrivateDnsZoneId
        ]
        subnetResourceId: subnetId
        tags: tags
      }
    ]
    diagnosticSettings: [
      {
        logCategoriesAndGroups: [
          {
            category: 'AzurePolicyEvaluationDetails'
          }
          {
            category: 'AuditEvent'
          }
        ]
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
}

resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' existing = {
  name: vaultName
} 

// This is used for Testing purposes only
// You could also pre-load secrets from pipeline variables or by reading another vault
resource keyVaultSecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = if (!isProductionDeployment) {
  parent: keyVault
  name: 'DevelopementTestSecret'
  dependsOn: [vault]
  properties: {
    value: 'Secret from the Vault'
  }
}

// Outputs
output keyVaultId string = vault.outputs.resourceId
output keyVaultName string = vault.outputs.name
