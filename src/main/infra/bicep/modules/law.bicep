

@description('location of the log analytics workspace')
param lawLocation string = resourceGroup().location
@description('name of the log analytics workspace')
param lawName string
@description('log analytics tags')
param lawTags object
@description('name of the kv to storing secrets')
param kvName string
@description('client shared key secret name')
param kvClientSharedKeySecretName string

var tags = union(lawTags,{
  Component : 'Monitoring'
})

// log analitics workspace
resource law 'Microsoft.OperationalInsights/workspaces@2020-03-01-preview' = {
  name: lawName
  location: lawLocation
  tags: tags
  properties: any({
    retentionInDays: 30
    features: {
      searchVersion: 1
    }
    sku: {
      name: 'PerGB2018'
    }
  })
}

// store the client key in a KV
resource kv 'Microsoft.KeyVault/vaults@2019-09-01' existing = {
  name: kvName
}

resource keyVaultSecretSharedKey 'Microsoft.KeyVault/vaults/secrets@2019-09-01' = {
  parent: kv
  name: kvClientSharedKeySecretName
  properties: {
    value: law.listKeys().primarySharedKey
  }
}


// outputs
output outputLawClientId string = law.properties.customerId
