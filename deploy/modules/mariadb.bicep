param location string
param namingStructure string
param allowSubnetId string

var storageMB = 5120
var dbName = 'craftcms'

resource mariadb 'Microsoft.DBforMariaDB/servers@2018-06-01' = {
  name: toLower(replace(namingStructure, '{rtype}', 'mariadb'))
  location: location
  sku: {
    name: 'GP_Gen5_2'
    tier: 'GeneralPurpose'
    capacity: 2
    family: 'Gen5'
    size: '${storageMB}'
  }
  properties: {
    administratorLogin: 'dbadmin'
    createMode: 'Default'
    administratorLoginPassword: 'Dbpassword1'
    // WARNING: Current version of Craft 3 and Craft 4 require at least 10.5
    version: '10.3'
    minimalTlsVersion: 'TLS1_2'
    storageProfile: {
      storageMB: storageMB
      backupRetentionDays: 7
      geoRedundantBackup: 'Disabled'
      storageAutogrow: 'Enabled'
    }
  }

  resource vnetRule 'virtualNetworkRules@2018-06-01' = {
    name: 'vnet-appSvc'
    properties: {
      virtualNetworkSubnetId: allowSubnetId
      ignoreMissingVnetServiceEndpoint: false
    }
  }
}

resource Db 'Microsoft.DBforMariaDB/servers/databases@2018-06-01' = {
  name: '${mariadb.name}/${dbName}'
  properties: {}
}

output fqdn string = mariadb.properties.fullyQualifiedDomainName
output dbName string = dbName
output serverName string = mariadb.name
