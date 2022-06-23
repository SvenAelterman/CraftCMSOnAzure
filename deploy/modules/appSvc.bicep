param location string
param namingStructure string
param environment string
param subnetId string
param crName string
param dockerImageAndTag string
param dbFqdn string
param databaseName string
param keyVaultName string

param dbUserNameSecretName string
param dbPasswordSecretName string
param craftSecurityKeySecretName string

module keyVaultRefs '../common-modules/appSvcKeyVaultRefs.bicep' = {
  name: 'appSvcKeyVaultRefs'
  params: {
    keyVaultName: keyVaultName
    secretNames: [
      dbUserNameSecretName
      dbPasswordSecretName
      craftSecurityKeySecretName
    ]
  }
}
var dbUserNameConfigValue = keyVaultRefs.outputs.keyVaultRefs[0]
var dbPasswordConfigValue = keyVaultRefs.outputs.keyVaultRefs[1]
var craftSecurityKeyConfigValue = keyVaultRefs.outputs.keyVaultRefs[2]

var linuxFx = 'DOCKER|${cr.properties.loginServer}/${dockerImageAndTag}'

var craftEnvMap = {
  demo: 'dev'
  dev: 'dev'
  test: 'production'
  prod: 'production'
}

// Create symbolic references to existing resources, to assign RBAC later
resource cr 'Microsoft.ContainerRegistry/registries@2021-12-01-preview' existing = {
  name: crName
}

resource kv 'Microsoft.KeyVault/vaults@2021-11-01-preview' existing = {
  name: keyVaultName
}

// Create an App Service Plan (the unit of compute and scale)
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

// Create an application service (the unit of deployment)
resource appSvc 'Microsoft.Web/sites@2021-03-01' = {
  name: webAppName
  location: location
  identity: {
    // Create a system assigned managed identity to read Key Vault and pull container images
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
}

module roles '../common-modules/roles.bicep' = {
  name: 'roles'
}

// Create an RBAC assignment to allow the app service's managed identity to pull images from the container registry
resource crRoleAssignment 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = {
  name: guid('rbac-${appSvc.name}-AcrPull')
  scope: cr
  properties: {
    roleDefinitionId: roles.outputs.roles['AcrPull']
    principalId: appSvc.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

// Create an RBAC assignment to allow the app service's managed identity to read Key Vault secrets
resource kvRoleAssignment 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = {
  name: guid('rbac-${appSvc.name}-SecretsUser')
  scope: kv
  properties: {
    roleDefinitionId: roles.outputs.roles['Key Vault Secrets User']
    principalId: appSvc.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

output appSvcPrincipalId string = appSvc.identity.principalId
output linuxFx string = linuxFx
output webAppName string = appSvc.name
