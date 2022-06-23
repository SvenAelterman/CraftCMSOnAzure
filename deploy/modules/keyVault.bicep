param location string
param kvName string

module roles '../common-modules/roles.bicep' = {
  name: 'roles'
}

resource kv 'Microsoft.KeyVault/vaults@2021-11-01-preview' = {
  name: kvName
  location: location
  properties: {
    sku: {
      name: 'standard'
      family: 'A'
    }
    tenantId: subscription().tenantId
    //enablePurgeProtection: false
    enableSoftDelete: false
    enableRbacAuthorization: true
  }
}

output keyVaultName string = kv.name

// TODO: Add secrets
