param location string
param namingStructure string
param subnetId string
param crName string
param dockerImageAndTag string
param dbFqdn string
param dbServerName string
param databaseName string

//param crResourceGroupName string = resourceGroup().name

var linuxFx = 'DOCKER|${cr.properties.loginServer}/${dockerImageAndTag}'

resource cr 'Microsoft.ContainerRegistry/registries@2021-12-01-preview' existing = {
  name: crName
  // Different subscription for the CR than for the app svc is not supported
  //scope: resourceGroup(crResourceGroupName)
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

var webAppName = replace(namingStructure, '{rtype}', 'app')

resource appSvc 'Microsoft.Web/sites@2021-03-01' = {
  name: webAppName
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

      appSettings: [
        {
          name: 'DOCKER_REGISTRY_SERVER_URL'
          value: 'https://${cr.properties.loginServer}'
        }
        {
          name: 'DB_DRIVER'
          value: 'mysql'
        }
        {
          name: 'DB_SERVER'
          value: dbFqdn
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
          name: 'WEBSITES_PORTS'
          value: '8080'
        }
        {
          name: 'WEBSITES_ENABLE_APP_SERVICE_STORAGE'
          value: 'false'
        }
        {
          name: 'SECURITY_KEY'
          value: 'CyteV8kbWB_4wvzyjS-PsjCkuGn5wXui'
        }
        {
          name: 'APP_ID'
          value: 'CraftCMS--0fbb0a77-7f67-40cb-9679-bd73cac7f8e4'
        }
        {
          name: 'ENVIRONMENT'
          value: 'dev'
        }
        {
          name: 'CP_TRIGGER'
          value: 'admin'
        }
        {
          name: 'PRIMARY_SITE_URL'
          // TODO: use actual app URL, must separate config from creation
          value: 'https://${webAppName}.azurewebsites.net'
        }
      ]
    }
  }
}

module roles '../common-modules/roles.bicep' = {
  name: 'roles'
}

// TODO: This applies to RBAC assignment to the resource group, should be scoped to the CR
resource roleAssignment 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = {
  name: guid('rbac-${appSvc.name}-AcrPull')
  scope: cr
  properties: {
    roleDefinitionId: roles.outputs.roles['AcrPull']
    principalId: appSvc.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

// TODO: Create RBAC assignment for App Svc mgd id to access KV

output appSvcPrincipalId string = appSvc.identity.principalId
output linuxFx string = linuxFx
output webAppName string = appSvc.name
