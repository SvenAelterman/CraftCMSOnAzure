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
	[string]$WorkloadName = 'craftcms',
	[int]$Sequence = 9,
	[string]$NamingConvention = "{rtype}-{wloadname}-{env}-{loc}-{seq}",
	[string]$WebsiteProjectName = "gafilmacademy"
)

$ImageName = "$($WorkloadName):latest"
$DbAdminUserName = "dbadmin"
[SecureString]$DbAdminPassword = (Get-Credential -UserName $DbAdminUserName -Message "Create a secure password for the database admin.").Password

$TemplateParameters = @{
	# REQUIRED
	location           = $Location
	environment        = $Environment
	workloadName       = $WorkloadName
	dbAdminPassword    = $DbAdminPassword
	dbAdminUserName    = $DbAdminUserName
	websiteProjectName = $WebSiteProjectName

	# OPTIONAL
	sequence           = $Sequence
	namingConvention   = $NamingConvention
	dockerImageAndTag  = $ImageName
	tags               = @{
		'date-created' = (Get-Date -Format 'yyyy-MM-dd')
		purpose        = $Environment
		lifetime       = 'short'
		'customer-ref' = 'UWG'
	}
}

$DeploymentResult = New-AzDeployment -Location $Location -Name "$WorkloadName-$Environment-$(Get-Date -Format 'yyyyMMddThhmmssZ' -AsUTC)" `
	-TemplateFile ".\main.bicep" -TemplateParameterObject $TemplateParameters

# Display the deployment result
$DeploymentResult

if ($DeploymentResult.ProvisioningState -eq 'Succeeded') {
	$Acr = $DeploymentResult.Outputs["acrName"].Value
	$WebAppName = $DeploymentResult.Outputs["webAppName"].Value
	$RgName = $DeploymentResult.Outputs["rgName"].Value

	az account set --subscription (Get-AzContext).Subscription.Id
	Write-Host "az acr build --image $ImageName --registry $Acr ../."

	# Build the container image, Dockerfile is in the parent folder (../.)
	az acr build --image $ImageName --registry $Acr ../.

	# Enable CD for container
	$ci_cd_url = az webapp deployment container config --name $WebAppName --resource-group $RgName --enable-cd true --query CI_CD_URL --output tsv

	$WebHookName = $NamingConvention.Replace('{rtype}', 'wh').Replace('{env}', $Environment).Replace('{loc}', $Location).Replace('{seq}', $Sequence).Replace('-', '')
	az acr webhook create --name $WebHookName --registry $Acr --resource-group $RgName --actions push --uri $ci_cd_url --scope $ImageName
}