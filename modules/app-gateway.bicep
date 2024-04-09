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

@description('The Http Host Name for the Application Gateway.')
param applicationHostName string

@description('The name of the Resource Group where the dependencies are deployed. This is initially used for SSL Certificates and default secrets.')
param dependenciesResourceGroupName string

@description('The name of the Key Vault where the dependencies are stored.')
param dependenciesKeyVaultName string

@description('The Name of the SSL Certificate to attach to the Application Gateway.')
param sslCertificateName string

@description('The Cloud Region for the deployment of core services and meta data.')
param cloudRegion string

@description('Indicates whether to deploy the resources in a zone redundant configuration.')
param deployZoneRedundantResources bool

@description('The name of the Virtual Network to attach the Application Gateway to.')
param virtualNetworkName string

@description('The name of the Subnet to attach the Application Gateway to.')
param subnetName string

@description('The backend address pools to attach to the Application Gateway.')
param backendAddressPools array

@description('The Resource Id of the Log Analytics Workspace where the diagnostic settings will be sent.')
param logAnalyticsWorkspaceResourceId string

@description('The tags to attach to the resources.')
param tags object

// Variables
var applicationAndEnvironmentName = toLower(replace('${applicationName}-${environmentName}-${cloudRegion}', ' ', '-'))
var applicationGatewayIdentityName = 'uami-app-gw-${applicationAndEnvironmentName}'
var applicationGatewayName = 'app-gw-${applicationAndEnvironmentName}'
var firewallPolicyName = 'fw-pol-${applicationAndEnvironmentName}'
var keyVaultRoleAssignmentName = 'app-gw-key-vault-role-assignment-${applicationAndEnvironmentName}'
var publicIpName = 'pip-${applicationAndEnvironmentName}'
var httpPortName = 'http_port_80'
var httpsPortName = 'https_port_443'
var backendAddressPoolName = 'backend-pool-1'
var gatewayIpConfigurationName = 'gateway-ip-configuration-1'
var frontEndIpConfigurationName = 'front-end-ip-configuration'
var backendHttpSettingsName = 'backend-http-setting-1'
var backendHttpsSettingsName = 'backend-https-setting-1'
var httpListenerName = 'http-listener-1'
var httpsListenerName = 'https-listener-1'
var httpRoutingRuleName = 'http-routing-rule-1'
var httpsRoutingRuleName = 'https-routing-rule-1'
var redirectConfigurationName = 'redirect-http-to-https'
var keyVaultertificateUserRoleId = 'db79e9a7-68ee-4b58-9aeb-b90e7c24fcba' // Key Vault Certificate User

// User Assigned Identity for App Gateway
resource appGatewayIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: applicationGatewayIdentityName
  location: cloudRegion
}

// Provide the App Gatway User with access to the Dependencies Key Vault (for SSL Certificates)
module kvRoleAssignment 'app-gateway-identity-role-assignment.bicep' = {
  name: keyVaultRoleAssignmentName
  scope: resourceGroup(dependenciesResourceGroupName)
  params: {
    keyVaultName: dependenciesKeyVaultName
    roleDefinitionId: keyVaultertificateUserRoleId
    principalId: appGatewayIdentity.properties.principalId
  }
}

// Public IP Address
module publicIpAddress 'networking-public-ipv4-address.bicep' = {
  name: publicIpName
  params: {
    publicIpAddressName: publicIpName
    cloudRegion: cloudRegion
    deployZoneRedundantResources: deployZoneRedundantResources
    tags: tags
  }
}

// Firewall Policy
module firewallPolicy 'app-gateway-firewall-policy.bicep' = {
  name: firewallPolicyName
  params: {
    firewallPolicyName: firewallPolicyName
    cloudRegion: cloudRegion
    tags: tags
  }
}

// The Key Vault
resource dependencyKeyVault 'Microsoft.KeyVault/vaults@2023-07-01' existing = {
  name: dependenciesKeyVaultName
  scope: resourceGroup(dependenciesResourceGroupName)
}

// Deploy the App Gateway
resource applicationGateway 'Microsoft.Network/applicationGateways@2021-05-01' = {
  name: applicationGatewayName
  location: cloudRegion
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${appGatewayIdentity.id}': {}
    }
  }
  properties: {
    sku: {
      name: 'WAF_v2'
      tier: 'WAF_v2'
    }
    enableHttp2: true
    autoscaleConfiguration: {
      minCapacity: 0
      maxCapacity: 10
    }
    firewallPolicy: {
      id: firewallPolicy.outputs.firewallPolicyId
    }
    sslCertificates: [
      {
        name: sslCertificateName
        properties: {
          keyVaultSecretId: '${dependencyKeyVault.properties.vaultUri}secrets/${sslCertificateName}'
        }
      }
    ]
    gatewayIPConfigurations: [
      {
        name: gatewayIpConfigurationName
        properties: {
          subnet: {
            id: resourceId('Microsoft.Network/virtualNetworks/subnets', virtualNetworkName, subnetName)
          }
        }
      }
    ]
    frontendIPConfigurations: [
      {
        name: frontEndIpConfigurationName
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: resourceId('Microsoft.Network/publicIPAddresses', publicIpName)
          }
        }
      }
    ]
    frontendPorts: [
      {
        name: httpPortName
        properties: {
          port: 80
        }
      }
      {
        name: httpsPortName
        properties: {
          port: 443
        }
      }
    ]
    backendAddressPools: [
      {
        name: backendAddressPoolName
        properties: {
          backendAddresses: flatten(backendAddressPools)
        }
      }
    ]
    backendHttpSettingsCollection: [
      {
        name: backendHttpSettingsName
        properties: {
          port: 80
          protocol: 'Http'
          cookieBasedAffinity: 'Disabled'
          pickHostNameFromBackendAddress: true
          requestTimeout: 60
        }
      }
      {
        name: backendHttpsSettingsName
        properties: {
          port: 443
          protocol: 'Https'
          cookieBasedAffinity: 'Disabled'
          pickHostNameFromBackendAddress: true
          requestTimeout: 60
        }
      }
    ]
    httpListeners: [
      {
        name: httpListenerName
        properties: {
          protocol: 'Http'
          requireServerNameIndication: false
          hostName: applicationHostName
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendIPConfigurations', applicationGatewayName, frontEndIpConfigurationName)
          }
          frontendPort: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendPorts', applicationGatewayName, httpPortName)
          }
        }
      }
      {
        name: httpsListenerName
        properties: {
          protocol: 'Https'
          requireServerNameIndication: false
          hostName: applicationHostName
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendIPConfigurations', applicationGatewayName, frontEndIpConfigurationName)
          }
          frontendPort: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendPorts', applicationGatewayName, httpsPortName)
          }
          sslCertificate: {
            id: resourceId('Microsoft.Network/applicationGateways/sslCertificates', applicationGatewayName, sslCertificateName)
          }
        }
      }
    ]
    requestRoutingRules: [
      {
        name: httpsRoutingRuleName
        properties: {
          ruleType: 'Basic'
          priority: 100
          httpListener: {
            id: resourceId('Microsoft.Network/applicationGateways/httpListeners', applicationGatewayName, httpsListenerName)
          }
          backendAddressPool: {
            id: resourceId('Microsoft.Network/applicationGateways/backendAddressPools', applicationGatewayName, backendAddressPoolName)
          }
          backendHttpSettings: {
            id: resourceId('Microsoft.Network/applicationGateways/backendHttpSettingsCollection', applicationGatewayName, backendHttpsSettingsName)
          }
        }
      }
      {
        name: httpRoutingRuleName
        properties: {
          ruleType: 'Basic'
          priority: 110
          httpListener: {
            id: resourceId('Microsoft.Network/applicationGateways/httpListeners', applicationGatewayName, httpListenerName)
          }
          redirectConfiguration: {
            id: resourceId('Microsoft.Network/applicationGateways/redirectConfigurations', applicationGatewayName, redirectConfigurationName)
          }
        }
      }
    ]
    redirectConfigurations: [
      {
        name: redirectConfigurationName
        properties: {
          redirectType: 'Permanent'
          includePath: true
          includeQueryString: true
          targetListener: {
            id: resourceId('Microsoft.Network/applicationGateways/httpListeners', applicationGatewayName, httpsListenerName)
          }
          requestRoutingRules: [
            {
              id: resourceId('Microsoft.Network/applicationGateways/requestRoutingRules', applicationGatewayName, httpRoutingRuleName)
            }
          ]
        }
      }
    ]
  }
  zones: (deployZoneRedundantResources) ? [
    '1'
    '2'
    '3'
  ] : []
  tags: tags
  dependsOn: [
    publicIpAddress
    firewallPolicy
    kvRoleAssignment
  ]
}

// Deploy the Diagnostic Settings
module diagnosticSettings 'app-gateway-diagnostic-settings.bicep' = {
  name: '${applicationAndEnvironmentName}-diagnostic-settings'
  params: {
    applicationGatewayName: applicationGateway.name
    logAnalyticsWorkspaceResourceId: logAnalyticsWorkspaceResourceId
  }
}


// Outputs
output applicationGatewayId string = applicationGateway.id
output applicationGatewayName string = applicationGateway.name
output publicIpv4AddressName string = publicIpAddress.name
output publicIpv4Address string = publicIpAddress.outputs.ipv4Address
