
@description('The name of the Resource Group where the dependencies are deployed.')
param dependenciesResourceGroupName string

@description('The name of the Key Vault where the dependencies are stored.')
param dependenciesKeyVaultName string

@description('The name of the Resource Group where the Key Vault is deployed.')
param targetResourceGroupName string

@description('The name of the target Key Vault.')
param targetKeyVaultName string

@description('An array of secret names to be copied.')
param keyNames array

// Seed the required secrets from the Dependencies Key Vault
// Get a Reference to the Dependencies Vault
resource dependenciesVault 'Microsoft.KeyVault/vaults@2023-07-01' existing = {
  name: dependenciesKeyVaultName
  scope: resourceGroup(dependenciesResourceGroupName)
}

resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' existing = {
  name: targetKeyVaultName
  scope: resourceGroup(targetResourceGroupName)
}

// Save the Dependencies to the new Key Vault
// Repeat for each of the secrets.
module saveApiKeySecret 'keyvault-set-secret.bicep' = [for i in range(0, length(keyNames)): {
  name: '${uniqueString(deployment().name)}-saveApiKeySecret-${i}'
  params: {
    keyVaultName: keyVault.name
    secretName: keyNames[i]
    secretValue: dependenciesVault.getSecret(keyNames[i])
  }
  dependsOn: [
    keyVault
    dependenciesVault
  ]
}]
