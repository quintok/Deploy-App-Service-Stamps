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

@description('The daily quota in GB for the workspace.')
param dailyQuotaGb int

@description('The number of days to retain data.')
param dataRetentionInDays int

@description('The Cloud Region where the resources will be deployed.')
param cloudRegion string = resourceGroup().location

@description('The tags to be applied to the resources.')
param tags object

// Variables
var isProductionDeployment = contains(environmentName, 'prod')
var applicationAndEnvironmentName = toLower(replace('${applicationName}-${environmentName}-${cloudRegion}', ' ', '-'))
var logAnalyticsWorkspaceName = toLower('law-${applicationAndEnvironmentName}')
var appInsightsName = toLower('app-insights-${applicationAndEnvironmentName}')

// Create the Log Analytics Workspace
module workspace 'br/public:avm/res/operational-insights/workspace:0.3.4' = {
  name: '${uniqueString(deployment().name)}-law'
  params: {
    name: logAnalyticsWorkspaceName
    location: cloudRegion
    dailyQuotaGb: dailyQuotaGb
    dataRetention: dataRetentionInDays
    publicNetworkAccessForIngestion: 'Disabled'
    publicNetworkAccessForQuery: 'Disabled'
    useResourcePermissions: true
    dataSources: [
      {
        eventLogName: 'Application'
        eventTypes: [
          {
            eventType: 'Error'
          }
          {
            eventType: 'Warning'
          }
          {
            eventType: 'Information'
          }
        ]
        kind: 'WindowsEvent'
        name: 'applicationEvent'
      }
      {
        counterName: '% Processor Time'
        instanceName: '*'
        intervalSeconds: 300
        kind: 'WindowsPerformanceCounter'
        name: 'windowsPerfCounter1'
        objectName: 'Processor'
      }
      {
        kind: 'IISLogs'
        name: 'sampleIISLog1'
        state: 'OnPremiseEnabled'
      }
      {
        kind: 'LinuxSyslog'
        name: 'sampleSyslog1'
        syslogName: 'kern'
        syslogSeverities: [
          {
            severity: 'emerg'
          }
          {
            severity: 'alert'
          }
          {
            severity: 'crit'
          }
          {
            severity: 'err'
          }
          {
            severity: 'warning'
          }
        ]
      }
      {
        kind: 'LinuxSyslogCollection'
        name: 'sampleSyslogCollection1'
        state: 'Enabled'
      }
      {
        instanceName: '*'
        intervalSeconds: 300
        kind: 'LinuxPerformanceObject'
        name: 'sampleLinuxPerf1'
        objectName: 'Logical Disk'
        syslogSeverities: [
          {
            counterName: '% Used Inodes'
          }
          {
            counterName: 'Free Megabytes'
          }
          {
            counterName: '% Used Space'
          }
          {
            counterName: 'Disk Transfers/sec'
          }
          {
            counterName: 'Disk Reads/sec'
          }
          {
            counterName: 'Disk Writes/sec'
          }
        ]
      }
      {
        kind: 'LinuxPerformanceCollection'
        name: 'sampleLinuxPerfCollection1'
        state: 'Enabled'
      }
    ]
    managedIdentities: {
      systemAssigned: true
    }
    lock: (isProductionDeployment) ? {
      kind: 'CanNotDelete'
      name: 'do-not-delete'
    } : {}
    tags: tags
  }
}

// Application Insights
module appinsights 'br/public:avm/res/insights/component:0.3.0' = {
  name: '${uniqueString(deployment().name)}-app-insights'
  params: {
    name: appInsightsName
    workspaceResourceId: workspace.outputs.resourceId
    location: cloudRegion
    tags: tags
  }
}

output logAnalyticsWorkspaceResourceId string = workspace.outputs.resourceId
output appInsightsResourceId string = appinsights.outputs.resourceId
output appInsightsConnectionString string = appinsights.outputs.connectionString
