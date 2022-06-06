param location string
param namingStructure string
param delegateSubnetId string
param virtualNetworkId string
param virtualNetworkName string

var storageGB = 20
var dbName = 'craftcms'
var mySQLServerName = toLower(replace(namingStructure, '{rtype}', 'mysql'))

resource dnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: '${mySQLServerName}.private.mysql.database.azure.com'
  location: 'global'
}

resource dnsZoneVnetLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  name: '${dnsZone.name}/${virtualNetworkName}'
  location: 'global'
  properties: {
    virtualNetwork: {
      id: virtualNetworkId
    }
    registrationEnabled: false
  }
}

resource mySQL 'Microsoft.DBforMySQL/flexibleServers@2021-05-01' = {
  name: mySQLServerName
  location: location
  dependsOn: [
    dnsZoneVnetLink
  ]
  sku: {
    name: 'Standard_D2ds_v4'
    tier: 'GeneralPurpose'
    //capacity: 2
  }
  properties: {
    administratorLogin: 'dbadmin'
    // TODO: Make sure to parametrize
    administratorLoginPassword: 'Dbpassword1'
    storage: {
      autoGrow: 'Enabled'
      iops: 360
      storageSizeGB: storageGB
    }
    version: '5.7'
    backup: {
      geoRedundantBackup: 'Disabled'
      backupRetentionDays: 7
    }
    network: {
      delegatedSubnetResourceId: delegateSubnetId
      privateDnsZoneResourceId: dnsZone.id
    }
  }
}

// Turn off requirement for TLS to connect to MySQL as Craft does not appear to support it
resource dbConfig 'Microsoft.DBForMySql/flexibleServers/configurations@2021-05-01' = {
  name: '${mySQL.name}/require_secure_transport'
  properties: {
    value: 'OFF'
    source: 'user-override'
  }
}

// resource db 'Microsoft.DBforMySQL/flexibleServers/databases@2021-05-01' = {
//   name: '${mySQL.name}/${dbName}'
//   properties: {
//     charset: 'utf8'
//     collation: 'utf8_general_ci'
//   }
// }

output fqdn string = mySQL.properties.fullyQualifiedDomainName
output dbName string = dbName
output serverName string = mySQLServerName
