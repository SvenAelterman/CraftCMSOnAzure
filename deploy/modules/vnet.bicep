param location string
param namingStructure string

param addressPrefix string = '10.91.0.{octet4}'

var subnets = [
  {
    subnetName: 'sn-appgw'
    addressPrefix: '${replace(addressPrefix, '{octet4}', '0')}/25'
    delegation: ''
    serviceEndpoints: [
      {
        service: 'Microsoft.KeyVault'
        locations: [
          location
        ]
      }
    ]
  }
  {
    subnetName: 'sn-mysql'
    addressPrefix: '${replace(addressPrefix, '{octet4}', '128')}/26'
    delegation: 'Microsoft.DBforMySQL/flexibleServers'
    serviceEndpoints: []
  }
  {
    subnetName: 'sn-appSvc'
    addressPrefix: '${replace(addressPrefix, '{octet4}', '192')}/26'
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
  }
  // {
  //   subnetName: 'appGw'
  //   addressPrefix: '${replace(addressPrefix, '{octet3}', '3')}/24'
  //   delegation: '' //'Microsoft.Network/applicationGateways'
  //   serviceEndpoints: [
  //     {
  //       service: 'Microsoft.KeyVault'
  //       locations: [
  //         location
  //       ]
  //     }
  //   ]
  // }
  // TODO: Add Bastion subnet
]

resource vnet 'Microsoft.Network/virtualNetworks@2021-08-01' = {
  name: replace(namingStructure, '{rtype}', 'vnet')
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '${replace(addressPrefix, '{octet4}', '0')}/24'
      ]
    }
    subnets: [for (subnet, i) in subnets: {
      name: subnet.subnetName
      properties: {
        addressPrefix: subnet.addressPrefix
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
