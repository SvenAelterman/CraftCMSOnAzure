param location string
param namingStructure string

resource acr 'Microsoft.ContainerRegistry/registries@2021-12-01-preview' = {
  // No hyphens allowed: https://docs.microsoft.com/en-us/azure/azure-resource-manager/management/resource-name-rules#microsoftcontainerregistry
  name: replace(replace(namingStructure, '{rtype}', 'cr'), '-', '')
  location: location
  sku: {
    name: 'Basic'
  }
}

output crName string = acr.name
output rgName string = resourceGroup().name
output acrLoginServer string = acr.properties.loginServer
