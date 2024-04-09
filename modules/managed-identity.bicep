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

@description('The tags to attach to the resources.')
param tags object

// Variables
var isProductionDeployment = contains(environmentName, 'prod')
var applicationAndEnvironmentName = toLower(replace('${applicationName}-${environmentName}-${cloudRegion}', ' ', '-'))
var gitHubIdentityName = toLower('github-identity-${applicationAndEnvironmentName}')

// Create the Managed Identity
module gitHubDeploymentManagedIdentity 'br/public:avm/res/managed-identity/user-assigned-identity:0.2.1' = {
  name: '${uniqueString(deployment().name)}-${environmentName}-github-identity'
  params: {
    name: gitHubIdentityName
    location: cloudRegion
    federatedIdentityCredentials: [
      {
        audiences: [
          'api://AzureADTokenExchange'
        ]
        name: 'creds-${applicationName}-${environmentName}-${cloudRegion}'
        subject: 'repo:sorvaag/HelloAppService:environment:production'
        issuer: 'https://token.actions.githubusercontent.com'
      }
    ]
    lock: (isProductionDeployment) ? {
      kind: 'CanNotDelete'
      name: 'do-not-delete'
    } : {}
    tags: tags
  }
}

// Outputs
output gitHubDeploymentManagedIdentityName string = gitHubDeploymentManagedIdentity.outputs.name
output gitHubIdentityClientId string = gitHubDeploymentManagedIdentity.outputs.clientId
output gitHubIdentityPrincipalId string = gitHubDeploymentManagedIdentity.outputs.principalId
