@description('The name of the Key Vault.')
param keyVaultName string

@description('The name of the secret in the Key Vault.')
param secretName string

@secure()
@description('The name of the secret in the Key Vault.')
param secretValue string

// The Dependencies Key Vault
resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' existing = {
  name: keyVaultName
}

// Save the Secret to the Key Vault
resource keyVaultSecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: secretName
  properties: {
    value: secretValue
  }
}
