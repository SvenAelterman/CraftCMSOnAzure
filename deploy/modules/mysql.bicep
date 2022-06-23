param location string
param namingStructure string
param delegateSubnetId string
param virtualNetworkId string
param virtualNetworkName string

@secure()
param dbAdminPassword string
param dbAdminUserName string = 'dbadmin'

// Optional parameters (acceptable defaults)
param storageGB int = 20
param dbName string = 'craftcms'

// Construct the MySQL server name - must be lowercase
var mySQLServerName = toLower(replace(namingStructure, '{rtype}', 'mysql'))

// Create a private DNS zone to host the MySQL Flexible Server records
resource dnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: '${mySQLServerName}.private.mysql.database.azure.com'
  location: 'global'
}

// Link the private DNS zone to the workload VNet
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

// Create the MySQL Flexible Server
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
    administratorLogin: dbAdminUserName
    administratorLoginPassword: dbAdminPassword
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
//var isNewDeployment = true // contains(mySQL.tags, existenceTagName)

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
    //isNewDeployment: isNewDeployment
    mySqlName: mySQL.name
    dbName: dbName
  }
}

output fqdn string = mySQL.properties.fullyQualifiedDomainName
output dbName string = dbName
output serverName string = mySQLServerName
output id string = mySQL.id
