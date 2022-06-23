param location string
param namingStructure string
param delegateSubnetId string
param virtualNetworkId string
param virtualNetworkName string
param existenceTagName string

var storageGB = 20
// TODO: Param?
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

// Determine if this is a new deployment based on the existence of a tag
var isNewDeployment = false // contains(mySQL.tags, existenceTagName)

// Turn off requirement for TLS to connect to MySQL as Craft does not appear to support it
resource dbConfig 'Microsoft.DBForMySql/flexibleServers/configurations@2021-05-01' = {
  name: '${mySQL.name}/require_secure_transport'
  properties: {
    value: 'OFF'
    source: 'user-override'
  }
}

// Deploy a database, if this is a new server deployment only
module db 'mysql-db.bicep' = {
  name: 'db'
  params: {
    isNewDeployment: isNewDeployment
    mySqlName: mySQL.name
    dbName: dbName
  }
}

// It's safe to always deploy the tag
resource mysqlTag 'Microsoft.Resources/tags@2021-04-01' = {
  name: 'default'
  scope: mySQL
  properties: {
    tags: {
      // The tag does not need to have a value
      // LATER: could improve this by setting value to the current time
      '${existenceTagName}': ''
    }
  }
  dependsOn: [
    db
  ]
}

output fqdn string = mySQL.properties.fullyQualifiedDomainName
output dbName string = dbName
output serverName string = mySQLServerName
output isNewDeployment bool = isNewDeployment
output id string = mySQL.id
