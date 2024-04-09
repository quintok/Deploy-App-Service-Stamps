@description('The Id of the Role Definition to assign to the Identity')
param roleDefinitionId string

@description('The Application Gateway Identity Principal ID to assign the role to.')
param principalId string

@description('The name of the Application Gateway to attach these diagnostic settings to.')
param keyVaultName string

// Get a reference to the Application Gateway
resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' existing = {
  name: keyVaultName
  scope: resourceGroup()
}

// Assign the Role to the Identity
resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(keyVaultName, roleDefinitionId, 'kv-role-assignment')
  scope: keyVault
  properties: {
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', roleDefinitionId)
    principalId: principalId
    principalType: 'ServicePrincipal'
  }
}
