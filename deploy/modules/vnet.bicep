param location string
param namingStructure string

var addressPrefix = '10.22.{octet3}.0'

var subnets = [
  {
    subnetName: 'default'
    delegation: ''
    serviceEndpoints: [
      {
        service: 'Microsoft.Storage'
        locations: [
          location
        ]
      }
      {
        service: 'Microsoft.KeyVault'
        locations: [
          location
        ]
      }
    ]
  }
  {
    subnetName: 'mysql'
    delegation: 'Microsoft.DBforMySQL/flexibleServers'
    serviceEndpoints: []
  }
  {
    subnetName: 'appSvc'
    delegation: 'Microsoft.Web/serverFarms'
    serviceEndpoints: [
      {
        service: 'Microsoft.Storage'
        locations: [
          location
        ]
      }
      {
        service: 'Microsoft.KeyVault'
        locations: [
          location
        ]
      }
    ]
    // LATER: Consider service endpoint policy to avoid data exfil to another storage account
    // TODO: Add App Gateway and Bastion subnets
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
        serviceEndpoints: !empty(subnet.serviceEndpoints) ? subnet.serviceEndpoints : null
      }
    }]
  }
}

output subnets array = vnet.properties.subnets
output vnetName string = vnet.name
output vnetId string = vnet.id
