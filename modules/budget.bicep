targetScope = 'subscription'

@description('The name of the budget.')
param budgetName string

@description('The Cloud Region for the deployment.')
param cloudRegion string

@description('Associates the budget with this set of resource groups.')
param resourceGroups array

@description('The email addresses to notify when the budget is exceeded.')
param alertEmailAddresses array

@description('The budget value.')
param budgetValue int

// Create the Budget
module budget 'br/public:avm/res/consumption/budget:0.3.1' = {
  name: '${uniqueString(deployment().name)}-budget'
  params: {
    name: toLower(budgetName)
    amount: budgetValue
    contactEmails: alertEmailAddresses
    location: cloudRegion
    // startDate: '2024-01-01'
    // endDate: '2050-12-31'
    resourceGroupFilter: resourceGroups
    thresholds: [
      80
      90
      100
      115
      130
    ]
  }
}
