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

param websiteProjectName string

// Optional parameters
param tags object = {}
param sequence int = 1
param namingConvention string = '{rtype}-{wloadname}-{env}-{loc}-{seq}'
param useMySql bool = true
param dockerImageAndTag string = 'craftcms:latest'

var sequenceFormatted = format('{0:00}', sequence)

// Naming structure only needs the resource type ({rtype}) replaced
var rgNamingStructure = replace(replace(replace(namingConvention, '{env}', environment), '{loc}', location), '{seq}', sequenceFormatted)
var namingStructure = replace(rgNamingStructure, '{wloadname}', workloadName)

var dbUserNameSecretName = 'mysql-username'
var dbPasswordSecretName = 'mysql-password'
var craftSecurityKeySecretName = 'craft-securitykey'

// Create multiple resource groups for governance
var rgBaseName = replace(rgNamingStructure, '{rtype}', 'rg')

resource dataRg 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: replace(rgBaseName, '{wloadname}', 'data')
  location: location
  tags: tags
}

resource sharedRg 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: replace(rgBaseName, '{wloadname}', 'shared')
  location: location
  tags: tags
}

resource projectRg 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: replace(rgBaseName, '{wloadname}', websiteProjectName)
  location: location
  tags: tags
}

resource networkRg 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: replace(rgBaseName, '{wloadname}', 'networking')
  location: location
  tags: tags
}

resource appSvcPlanRg 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: replace(rgBaseName, '{wloadname}', 'appservice')
  location: location
  tags: tags
}

module acr 'modules/cr.bicep' = {
  name: 'cr'
  scope: sharedRg
  params: {
    location: location
    namingStructure: namingStructure
  }
}

module vnet 'modules/vnet.bicep' = {
  name: 'vnet'
  scope: networkRg
  params: {
    location: location
    namingStructure: namingStructure
  }
}

// LATER: (prod) Consider putting data in separate RG
module mariadb 'modules/mariadb.bicep' = if (!useMySql) {
  name: 'mariadb'
  scope: dataRg
  params: {
    location: location
    namingStructure: namingStructure
    allowSubnetId: vnet.outputs.subnets[2].id // AppSvc subnet
  }
}

module mysqlModule 'modules/mysql.bicep' = if (useMySql) {
  name: 'mysql'
  scope: dataRg
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
  scope: sharedRg
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
  scope: sharedRg
  params: {
    location: location
    kvName: kvShortName.outputs.shortName
    subnets: [
      vnet.outputs.subnets[2].id // appSvc
      vnet.outputs.subnets[0].id // AppGw
    ]
  }
}

module kvSecrets 'modules/keyVaultSecrets.bicep' = {
  name: 'kv-secrets'
  scope: sharedRg
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

module appSvc 'modules/appSvc-support.bicep' = {
  name: 'appSvc'
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
    crResourceGroupName: sharedRg.name
    projectResourceGroupName: projectRg.name
    appSvcPlanResourceGroupName: appSvcPlanRg.name
    projectName: websiteProjectName
    // TODO: Rename parameter
    appSvcNamingStructure: rgNamingStructure
    tags: tags
  }
  dependsOn: [
    kv
  ]
}

// TODO: Complete module
// module appInsights 'modules/appInsights.bicep' = {
//   name: 'appInsights'
//   scope: projectRg
// }

// Create a name for the new storage account
// LATER: Add a randomization factor
module stShortName 'common-modules/shortname.bicep' = {
  name: 'stShortName'
  scope: projectRg
  params: {
    environment: environment
    location: location
    namingConvention: namingConvention
    resourceType: 'st'
    workloadName: websiteProjectName
    maxLength: 23
    removeHyphens: true
    sequence: sequence
    lowerCase: true
  }
}

module storage 'modules/storageAccount.bicep' = {
  name: 'storage'
  scope: projectRg
  params: {
    location: location
    storageAccountName: stShortName.outputs.shortName
    blobContainerName: workloadName
    virtualNetworkId: vnet.outputs.vnetId
    subnets: [
      vnet.outputs.subnets[2] // appSvc
    ]
  }
}

// module AppGwModule 'modules/appGw.bicep' = {
//   name: 'appGw'
//   scope: networkRg
//   params: {
//     location: location
//     appSvcName: appSvc.outputs.webAppName
//     keyVaultName: kv.outputs.keyVaultName
//     namingStructure: namingStructure
//     subnetName: 'AppGw'
//     vnetName: vnet.outputs.vnetName
//   }
// }

// TODO: Mount storage in craft CMS

output namingStructure string = namingStructure
output acrLoginServer string = acr.outputs.acrLoginServer
output linuxFx string = appSvc.outputs.linuxFx
output acrName string = acr.outputs.crName
output webAppName string = appSvc.outputs.webAppName
//output rgName string = rg.name
