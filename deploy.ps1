$today=Get-Date -Format "yyyy-MM-dd-HH-mm-ss"
$deploymentName="Deployment-$today"

New-AzSubscriptionDeployment -Name $deploymentName -Location "australiaeast" -TemplateFile .\main-single-subscription.bicep -TemplateParameterFile .\parameters\main-single-subscription.dev.parameters.json -DeploymentDebugLogLevel All