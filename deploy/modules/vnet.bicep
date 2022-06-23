param location string
param namingStructure string

var addressPrefix = '10.22.{octet3}.0'

var subnets = [
  {
    subnetName: 'default'
    delegation: ''
  }
  {
    subnetName: 'mysql'
    delegation: 'Microsoft.DBforMySQL/flexibleServers'
  }
  {
    subnetName: 'appSvc'
    delegation: 'Microsoft.Web/serverFarms'
    serviceEndpoints: [
      'Microsoft.Storage'
    ]
    // LATER: Consider service endpoint policy to avoid data exfil to another storage account
  }
]

resource vnet 'Microsoft.Network/virtualNetworks@2021-08-01' = {
  name: replace(namingStructure, '{rtype}', 'vnet')
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '${replace(addressPrefix, '{octet3}', '0')}/16'
      ]
    }
    subnets: [for (subnet, i) in subnets: {
      name: subnet.subnetName
      properties: {
        addressPrefix: '${replace(addressPrefix, '{octet3}', string(i))}/24'
        delegations: (empty(subnet.delegation) ? null : [
          {
            name: 'delegation'
            properties: {
              serviceName: subnet.delegation
            }
          }
        ])
        // TODO: Process any service endpoints
      }
    }]
  }
}

output subnets array = vnet.properties.subnets
output vnetName string = vnet.name
output vnetId string = vnet.id
