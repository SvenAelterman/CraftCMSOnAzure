param location string
param kvName string
param subnets array

resource kv 'Microsoft.KeyVault/vaults@2021-11-01-preview' = {
  name: kvName
  location: location
  properties: {
    sku: {
      name: 'standard'
      family: 'A'
    }
    tenantId: subscription().tenantId
    enableSoftDelete: false
    enableRbacAuthorization: true

    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Deny'
      virtualNetworkRules: [for subnet in subnets: {
        id: subnet
        ignoreMissingVnetServiceEndpoint: false
      }]
    }
  }
}

output keyVaultName string = kv.name
