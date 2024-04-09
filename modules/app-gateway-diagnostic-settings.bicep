@description('The name of the Application Gateway to attach these diagnostic settings to.')
param applicationGatewayName string

@description('The Resource Id of the Log Analytics Workspace where the diagnostic settings will be sent.')
param logAnalyticsWorkspaceResourceId string

// Get a reference to the Application Gateway
resource applicationGateway 'Microsoft.Network/applicationGateways@2021-02-01' existing = {
  name: applicationGatewayName
}

// Deploy the diagnostic settings for the Application Gateway
resource diagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'diagnosticSettings'
  scope: applicationGateway
  properties: {
    workspaceId: logAnalyticsWorkspaceResourceId
    logs: [
      {
        category: 'ApplicationGatewayAccessLog'
        enabled: true
      }
      {
        category: 'ApplicationGatewayPerformanceLog'
        enabled: true
      }
      {
        category: 'ApplicationGatewayFirewallLog'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}
