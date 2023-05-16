
@description('environnement name')
param caEnvName string 
@description('environnement location')
param caEnvLocation string = resourceGroup().location
@description('environnement tags')
param caEnvTags object = {}
@description('environnement log analytics name')
param caEnvLawName string
@description('environnement infra subnet id')
param caEnvVnetInfraSubnetId string
@description('set to true if the environnement is private, i.e vnet injected')
param caEnvPrivate bool = true
@description('set to true for zone redundant environnement')
param caEnvZoneRedundant bool = false
@description('name of th kv holidng secrets for connection to the log analytics')


var tags = union(caEnvTags, { 
  Component: 'ContainerAppEnv'
 } )

 //fetch the law in order to get the primary shared key below to avoid secret output 
resource law 'Microsoft.OperationalInsights/workspaces@2022-10-01' existing = {
  name: caEnvLawName
}

resource capps 'Microsoft.App/managedEnvironments@2022-03-01' = {
  name: caEnvName
  location: caEnvLocation
  tags: tags
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: law.properties.customerId
        sharedKey: law.listKeys().primarySharedKey
      }
    }
    vnetConfiguration: {
      infrastructureSubnetId: caEnvVnetInfraSubnetId
      internal: caEnvPrivate
    }
    zoneRedundant: caEnvZoneRedundant
  }
}

output caEnvId string = capps.id
output caEnvDefaultDomain string = capps.properties.defaultDomain
output caEnvStaticIp string = capps.properties.staticIp

