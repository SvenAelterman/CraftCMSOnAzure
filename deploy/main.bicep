targetScope = 'subscription'

@allowed([
  'eastus2'
  'eastus'
])
param location string
@allowed([
  'test'
  'demo'
  'prod'
])
param environment string
param workloadName string

@secure()
param dbAdminPassword string
@secure()
param dbAdminUserName string

// Optional parameters
param tags object = {}
param sequence int = 1
param namingConvention string = '{rtype}-{wloadname}-{env}-{loc}-{seq}'
param useMySql bool = true
param dockerImageAndTag string = 'craftcms:latest'

var sequenceFormatted = format('{0:00}', sequence)

// Naming structure only needs the resource type ({rtype}) replaced
var namingStructure = replace(replace(replace(replace(namingConvention, '{env}', environment), '{loc}', location), '{seq}', sequenceFormatted), '{wloadname}', workloadName)

var dbUserNameSecretName = 'mysql-username'
var dbPasswordSecretName = 'mysql-password'
var craftSecurityKeySecretName = 'craft-securitykey'

resource rg 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: replace(namingStructure, '{rtype}', 'rg')
  location: location
  tags: tags
}

module acr 'modules/cr.bicep' = {
  name: 'cr'
  scope: rg
  params: {
    location: location
    namingStructure: namingStructure
  }
}

module vnet 'modules/vnet.bicep' = {
  name: 'vnet'
  scope: rg
  params: {
    location: location
    namingStructure: namingStructure
  }
}

// LATER: (prod) Consider putting data in separate RG
module mariadb 'modules/mariadb.bicep' = if (!useMySql) {
  name: 'mariadb'
  scope: rg
  params: {
    location: location
    namingStructure: namingStructure
    allowSubnetId: vnet.outputs.subnets[2].id // AppSvc subnet
  }
}

module mysqlModule 'modules/mysql.bicep' = if (useMySql) {
  name: 'mysql'
  scope: rg
  params: {
    location: location
    namingStructure: namingStructure
    virtualNetworkId: vnet.outputs.vnetId
    virtualNetworkName: vnet.outputs.vnetName
    // The MySQL subnet in the vnet is the second entry in the array
    delegateSubnetId: vnet.outputs.subnets[1].id
    dbName: workloadName
    dbAdminUserName: 'dbadmin'
    dbAdminPassword: dbAdminPassword
  }
}

// Ensure the name of the Key Vault meets requirements
module kvShortName 'common-modules/shortname.bicep' = {
  name: 'kvShortName'
  scope: rg
  params: {
    location: location
    resourceType: 'kv'
    namingConvention: namingConvention
    workloadName: workloadName
    environment: environment
    sequence: sequence
    maxLength: 24
  }
}

module kv 'modules/keyVault.bicep' = {
  name: 'kv'
  scope: rg
  params: {
    location: location
    kvName: kvShortName.outputs.shortName
    subnets: [
      vnet.outputs.subnets[0].id // default
      vnet.outputs.subnets[2].id // appSvc
    ]
  }
}

module kvSecrets 'modules/keyVaultSecrets.bicep' = {
  name: 'kv-secrets'
  scope: rg
  params: {
    keyVaultName: kv.outputs.keyVaultName
    dbAdminPassword: dbAdminPassword
    dbAdminPasswordSecretName: dbPasswordSecretName
    dbAdminUserName: dbAdminUserName
    dbAdminUserNameSecretName: dbUserNameSecretName
    craftSecurityKey: 'CyteV8kbWB_4wvzyjS-PsjCkuGn5wXui'
    craftSecurityKeySecretName: craftSecurityKeySecretName
  }
}

module appSvc 'modules/appSvc.bicep' = {
  name: 'appSvc'
  scope: rg
  params: {
    location: location
    namingStructure: namingStructure
    environment: environment
    subnetId: vnet.outputs.subnets[2].id
    crName: acr.outputs.crName
    dockerImageAndTag: dockerImageAndTag
    dbFqdn: useMySql ? mysqlModule.outputs.fqdn : mariadb.outputs.fqdn
    databaseName: useMySql ? mysqlModule.outputs.dbName : mariadb.outputs.dbName

    // The names of the secrets in the Key Vault
    craftSecurityKeySecretName: craftSecurityKeySecretName
    dbPasswordSecretName: dbPasswordSecretName
    dbUserNameSecretName: dbUserNameSecretName
    // The name of the Key Vault
    keyVaultName: kv.outputs.keyVaultName
  }
  dependsOn: [
    kv
  ]
}

module appInsights 'modules/appInsights.bicep' = {
  name: 'appInsights'
  scope: rg
}

// Create a name for the new storage account
// LATER: Add a randomization factor
module stShortName 'common-modules/shortname.bicep' = {
  name: 'stShortName'
  scope: rg
  params: {
    environment: environment
    location: location
    namingConvention: namingConvention
    resourceType: 'st'
    workloadName: workloadName
    maxLength: 23
    removeHyphens: true
    sequence: sequence
  }
}

module storage 'modules/storageAccount.bicep' = {
  name: 'storage'
  scope: rg
  params: {
    location: location
    storageAccountName: stShortName.outputs.shortName
    blobContainerName: workloadName
    virtualNetworkId: vnet.outputs.vnetId
    subnets: [
      vnet.outputs.subnets[0] // default
      vnet.outputs.subnets[2] // appSvc
    ]
  }
}

// TODO: Mount storage in craft CMS

output namingStructure string = namingStructure
output acrLoginServer string = acr.outputs.acrLoginServer
output linuxFx string = appSvc.outputs.linuxFx
output acrName string = acr.outputs.crName
output webAppName string = appSvc.outputs.webAppName
output rgName string = rg.name
