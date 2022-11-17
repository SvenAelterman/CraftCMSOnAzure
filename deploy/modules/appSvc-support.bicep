targetScope = 'subscription'

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

param crResourceGroupName string
// Default to all resources in the same RG (for dev/test deployments)
param kvResourceGroupName string = crResourceGroupName
param projectResourceGroupName string = crResourceGroupName
param appSvcPlanResourceGroupName string = crResourceGroupName

param appSvcNamingStructure string
param projectName string

param tags object = {}

var linuxFx = 'DOCKER|${cr.properties.loginServer}/${dockerImageAndTag}'

// Create symbolic references to existing resources, to assign RBAC later
resource crRg 'Microsoft.Resources/resourceGroups@2021-04-01' existing = {
  name: crResourceGroupName
}

resource kvRg 'Microsoft.Resources/resourceGroups@2021-04-01' existing = {
  name: kvResourceGroupName
}

resource appSvcPlanRg 'Microsoft.Resources/resourceGroups@2021-04-01' existing = {
  name: appSvcPlanResourceGroupName
}

resource cr 'Microsoft.ContainerRegistry/registries@2021-12-01-preview' existing = {
  name: crName
  scope: crRg
}

resource kv 'Microsoft.KeyVault/vaults@2021-11-01-preview' existing = {
  name: keyVaultName
  scope: kvRg
}

resource rg 'Microsoft.Resources/resourceGroups@2021-04-01' existing = {
  name: projectResourceGroupName
}

module keyVaultRefs '../common-modules/appSvcKeyVaultRefs.bicep' = {
  name: 'appSvcKeyVaultRefs'
  scope: kvRg
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

// Create an App Service Plan (the unit of compute and scale)
module appSvcPlanModule 'appSvcPlan.bicep' = {
  name: 'AppSvcPlanDeploy'
  scope: appSvcPlanRg
  params: {
    location: location
    namingStructure: namingStructure
  }
}

// Create an application service (the unit of code deployment)
var webAppName = replace(replace(appSvcNamingStructure, '{rtype}', 'app'), '{wloadname}', projectName)

module appSvcModule 'appSvc.bicep' = {
  name: 'AppSvcDeploy'
  scope: rg
  params: {
    location: location
    tags: tags
    databaseName: databaseName
    dbFqdn: dbFqdn
    linuxFx: linuxFx
    //namingStructure: namingStructure
    subnetId: subnetId
    webAppName: webAppName
    environment: environment
    craftSecurityKeyConfigValue: craftSecurityKeyConfigValue
    dbPasswordConfigValue: dbPasswordConfigValue
    dbUserNameConfigValue: dbUserNameConfigValue
    crLoginServer: cr.properties.loginServer
    appSvcPlanId: appSvcPlanModule.outputs.id
  }
}

module roles '../common-modules/roles.bicep' = {
  name: 'roles'
  scope: rg
}

// TODO: Process the role assignments in modules
// Create an RBAC assignment to allow the app service's managed identity to pull images from the container registry
// resource crRoleAssignment 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = {
//   name: guid('rbac-${webAppName}-AcrPull')
//   scope: cr
//   properties: {
//     roleDefinitionId: roles.outputs.roles.AcrPull
//     principalId: appSvcModule.outputs.principalId
//     principalType: 'ServicePrincipal'
//   }
// }

// // Create an RBAC assignment to allow the app service's managed identity to read Key Vault secrets
// resource kvRoleAssignment 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = {
//   name: guid('rbac-${webAppName}-SecretsUser')
//   scope: kv
//   properties: {
//     roleDefinitionId: roles.outputs.roles['Key Vault Secrets User']
//     principalId: appSvcModule.outputs.principalId
//     principalType: 'ServicePrincipal'
//   }
// }

output appSvcPrincipalId string = appSvcModule.outputs.principalId
output linuxFx string = linuxFx
output webAppName string = appSvcModule.outputs.appSvcName
