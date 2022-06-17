

@description('key vault name')
param kvName string
@description('kv location')
param kvLocation  string = resourceGroup().location

resource keyVault 'Microsoft.KeyVault/vaults@2019-09-01' = {
  name: kvName
  location: kvLocation
  properties: {
    enabledForTemplateDeployment: true
    enableSoftDelete: false
    tenantId: tenant().tenantId
    accessPolicies: [
    ]
    sku: {
      name: 'standard'
      family: 'A'
    }
  }
}
