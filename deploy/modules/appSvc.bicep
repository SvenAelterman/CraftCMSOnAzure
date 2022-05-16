param location string
param namingStructure string
param subnetId string
param crName string
param dockerImageAndTag string
param mariadbFqdn string
param mariadbServerName string
param databaseName string

param crResourceGroupName string = resourceGroup().name

var linuxFx = 'DOCKER|${cr.properties.loginServer}/${dockerImageAndTag}'

resource cr 'Microsoft.ContainerRegistry/registries@2021-12-01-preview' existing = {
  name: crName
  // Different subscription for the CR than for the app svc is not supported
  scope: resourceGroup(crResourceGroupName)
}

resource appSvcPlan 'Microsoft.Web/serverfarms@2021-03-01' = {
  name: toLower(replace(namingStructure, '{rtype}', 'plan'))
  location: location
  kind: 'Linux'
  sku: {
    name: 'S1'
    tier: 'Standard'
  }
  properties: {
    targetWorkerCount: 1
    targetWorkerSizeId: 0
    reserved: true
    zoneRedundant: false
  }
}

resource appSvc 'Microsoft.Web/sites@2021-03-01' = {
  name: replace(namingStructure, '{rtype}', 'app')
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  kind: 'app,linux,container'
  properties: {
    serverFarmId: appSvcPlan.id
    virtualNetworkSubnetId: subnetId
    httpsOnly: true
    keyVaultReferenceIdentity: 'SystemAssigned'

    siteConfig: {
      http20Enabled: true
      vnetRouteAllEnabled: true
      alwaysOn: true
      linuxFxVersion: linuxFx
      acrUseManagedIdentityCreds: true

      connectionStrings: [
        {
          // TODO: Params for username and pwd
          connectionString: 'Database=${databaseName};Data Source=${mariadbFqdn};User Id=dbadmin@${mariadbServerName};Password=Dbpassword1'
          name: 'dbstring'
          type: 'MySql'
        }
      ]

      appSettings: [
        {
          name: 'DOCKER_REGISTRY_SERVER_URL'
          value: 'https://${cr.properties.loginServer}'
        }
        // {
        //   name: 'DOCKER_REGISTRY_SERVER_USERNAME'
        //   value: 'adminUser'
        // }
        // {
        //   name: 'DOCKER_REGISTRY_SERVER_PASSWORD'
        //   value: cr.listCredentials().passwords[0].value
        // }
        {
          name: 'DB_DRIVER'
          value: 'mysql'
        }
        {
          name: 'DB_SERVER'
          value: mariadbFqdn
        }
        {
          name: 'DB_PORT'
          value: '3306'
        }
        {
          name: 'DB_DATABASE'
          value: databaseName
        }
        {
          name: 'DB_SCHEMA'
          value: 'public'
        }
        {
          name: 'DB_USER'
          // TODO: param
          value: 'dbadmin'
        }
        {
          name: 'DB_PASSWORD'
          // TODO: param and Key Vault
          value: 'Dbpassword1'
        }
        {
          name: 'WEB_IMAGE_PORTS'
          value: '80:8080'
        }
        {
          name: 'WEBSITES_ENABLE_APP_SERVICE_STORAGE'
          value: 'false'
        }
      ]
    }
  }
}

module roles '../common-modules/roles.bicep' = {
  name: 'roles'
}

resource roleAssignment 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = {
  name: guid('rbac-${appSvc.name}-AcrPull')
  properties: {
    roleDefinitionId: roles.outputs.roles['AcrPull']
    principalId: appSvc.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

output appSvcPrincipalId string = appSvc.identity.principalId
output linuxFx string = linuxFx
