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

// Optional parameters
param tags object = {}
param sequence int = 1
param namingConvention string = '{rtype}-{wloadname}-{env}-{loc}-{seq}'
param useMySql bool = true

var sequenceFormatted = format('{0:00}', sequence)

// Naming structure only needs the resource type ({rtype}) replaced
var namingStructure = replace(replace(replace(replace(namingConvention, '{env}', environment), '{loc}', location), '{seq}', sequenceFormatted), '{wloadname}', workloadName)

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

// TODO: consider putting data in separate RG
module mariadb 'modules/mariadb.bicep' = if (!useMySql) {
  name: 'mariadb'
  scope: rg
  params: {
    location: location
    namingStructure: namingStructure
    allowSubnetId: vnet.outputs.subnets[2].id
  }
}

module mysql 'modules/mysql.bicep' = if (useMySql) {
  name: 'mysql'
  scope: rg
  params: {
    location: location
    namingStructure: namingStructure
    virtualNetworkId: vnet.outputs.vnetId
    virtualNetworkName: vnet.outputs.vnetName
    // The mysql subnet
    delegateSubnetId: vnet.outputs.subnets[1].id
  }
}

// TODO: Add KV and secrets
module appSvc 'modules/appSvc.bicep' = {
  name: 'appSvc'
  scope: rg
  params: {
    location: location
    namingStructure: namingStructure
    subnetId: vnet.outputs.subnets[2].id
    dbServerName: useMySql ? mysql.outputs.serverName : mariadb.outputs.serverName
    crName: acr.outputs.crName
    // TODO: Param
    dockerImageAndTag: 'craftcms:latest'
    crResourceGroupName: acr.outputs.rgName
    dbFqdn: useMySql ? mysql.outputs.fqdn : mariadb.outputs.fqdn
    databaseName: useMySql ? mysql.outputs.dbName : mariadb.outputs.dbName
  }
}

// TODO: Storage account, blob container
// TODO: Mount storage in craft CMS

output namingStructure string = namingStructure
output acrLoginServer string = acr.outputs.acrLoginServer
output linuxFx string = appSvc.outputs.linuxFx
output acrName string = acr.outputs.crName
