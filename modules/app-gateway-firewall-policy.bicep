@description('The name of the Application Gateway Web Application Firewall Policy.')
param firewallPolicyName string

@description('The Cloud Region for the deployment of core services and meta data.')
param cloudRegion string

@description('The tags to attach to the resources.')
param tags object

resource firewallPolicy 'Microsoft.Network/ApplicationGatewayWebApplicationFirewallPolicies@2021-08-01' = {
  name: firewallPolicyName
  location: cloudRegion
  properties: {
    policySettings: {
      requestBodyCheck: true
      maxRequestBodySizeInKb: 128
      fileUploadLimitInMb: 100
      state: 'Enabled'
      mode: 'Prevention'
    }
    managedRules: {
      managedRuleSets: [
        {
          ruleSetType: 'OWASP'
          ruleSetVersion: '3.1'
        }
        {
          ruleSetType: 'Microsoft_BotManagerRuleSet'
          ruleSetVersion: '0.1'
        }
      ]
    }
  }
  tags: tags
}


// Outputs
output firewallPolicyId string = firewallPolicy.id
