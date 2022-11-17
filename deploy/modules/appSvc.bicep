param webAppName string
//param namingStructure string
param location string
param subnetId string
param dbFqdn string
param databaseName string
param linuxFx string
param environment string
param dbUserNameConfigValue string
param crLoginServer string
@secure()
param dbPasswordConfigValue string
param craftSecurityKeyConfigValue string
param appSvcPlanId string

param tags object = {}

var craftEnvMap = {
  demo: 'dev'
  dev: 'dev'
  test: 'production'
  prod: 'production'
}

resource appSvc 'Microsoft.Web/sites@2021-03-01' = {
  name: webAppName
  location: location
  identity: {
    // Create a system assigned managed identity to read Key Vault and pull container images
    type: 'SystemAssigned'
  }
  kind: 'app,linux,container'
  properties: {
    serverFarmId: appSvcPlanId
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
          value: 'https://${crLoginServer}'
        }
        {
          name: 'DB_DRIVER'
          value: 'mysql'
        }
        {
          name: 'DB_PORT'
          value: '3306'
        }
        {
          name: 'DB_SERVER'
          value: dbFqdn
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
          value: dbUserNameConfigValue
        }
        {
          name: 'DB_PASSWORD'
          value: dbPasswordConfigValue
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
          value: craftSecurityKeyConfigValue
          //value: 'CyteV8kbWB_4wvzyjS-PsjCkuGn5wXui'
        }
        {
          name: 'APP_ID'
          // LATER: Param for APP_ID - generate new GUID?
          value: 'CraftCMS--0fbb0a77-7f67-40cb-9679-bd73cac7f8e4'
        }
        {
          name: 'ENVIRONMENT'
          value: craftEnvMap[environment]
        }
        {
          name: 'CP_TRIGGER'
          value: 'admin'
        }
        {
          name: 'PRIMARY_SITE_URL'
          // LATER: use actual app URL, must separate config from creation?
          value: 'https://${webAppName}.azurewebsites.net'
        }
      ]
    }
  }
  tags: tags
}

output appSvcName string = appSvc.name
output principalId string = appSvc.identity.principalId
