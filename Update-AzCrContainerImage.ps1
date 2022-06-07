[int]$Sequence = 2
[string]$WorkloadName = 'craftcms'
[string]$Acr = "cr$($WorkloadName)demoeastus0$($Sequence)"

$ImageName = "$($WorkloadName):latest"

# Build the container image, Dockerfile is in the parent folder (../.)
az account set --subscription (Get-AzContext).Subscription.Id
Write-Host "az acr build --image $ImageName --registry $Acr ../."
az acr build --image $ImageName --registry $Acr .