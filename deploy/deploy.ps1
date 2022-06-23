# PowerShell script to deploy the main.bicep template with parameter values

#Requires -Modules "Az"
#Requires -PSEdition Core

# Use these parameters to customize the deployment instead of modifying the default parameter values
[CmdletBinding()]
Param(
	[ValidateSet('eastus2', 'eastus')]
	[string]$Location = 'eastus',
	# The environment descriptor
	[ValidateSet('test', 'demo', 'prod')]
	[string]$Environment = 'test',
	#
	[Parameter()]
	[string]$WorkloadName = 'craftcms',
	#
	[int]$Sequence = 1,
	[string]$NamingConvention = "{rtype}-$WorkloadName-{env}-{loc}-{seq}"
)

$TemplateParameters = @{
	# REQUIRED
	location         = $Location
	environment      = $Environment
	workloadName     = $WorkloadName

	# OPTIONAL
	sequence         = $Sequence
	namingConvention = $NamingConvention
	tags             = @{
		'date-created' = (Get-Date -Format 'yyyy-MM-dd')
		purpose        = $Environment
		lifetime       = 'short'
	}
}

$DeploymentResult = New-AzDeployment -Location $Location -Name "$WorkloadName-$Environment-$(Get-Date -Format 'yyyyMMddThhmmssZ' -AsUTC)" `
	-TemplateFile ".\main.bicep" -TemplateParameterObject $TemplateParameters

$DeploymentResult

if ($DeploymentResult.ProvisioningState -eq 'Succeeded') {
	# login to ACR?
	$Acr = $DeploymentResult.Outputs["acrName"].Value
	$WebAppName = $DeploymentResult.Outputs["webAppName"].Value
	$RgName = $DeploymentResult.Outputs["rgName"].Value
	$ImageName = "$($WorkloadName):latest"

	# Build the container image, Dockerfile is in the parent folder (../.)
	az account set --subscription (Get-AzContext).Subscription.Id
	Write-Host "az acr build --image $ImageName --registry $Acr ../."
	az acr build --image $ImageName --registry $Acr ../.

	# Enable CD for container
	$ci_cd_url = az webapp deployment container config --name $WebAppName --resource-group $RgName --enable-cd true --query CI_CD_URL --output tsv

	$ci_cd_url
	#$WebHookName = $NamingConvention.Replace('{rtype}', 'wh').Replace('{}')
	$WebHookName = 'whcraftcmsdemoeastus01'
	az acr webhook create --name $WebHookName --registry $Acr --resource-group $RgName --actions push --uri $ci_cd_url --scope $ImageName
}