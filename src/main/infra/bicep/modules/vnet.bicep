@description('vnet name')
param vnetName string = 'vnet'
@description('vnet CIDR')
param vnetPrefix string = '10.0.0.0/16'
@description('vnet subnets')
param vnetSubnets array = []
@description('vnet tags')
param vNetTags object = {}
@description('vnet location, override if necessary, use default in most cases')
param vNetLocation string = resourceGroup().location

var tags = union(vNetTags, {
    Component : 'Network'
})

// vnet with subnets
resource vnet 'Microsoft.Network/virtualNetworks@2019-12-01' = {
  name: vnetName
  location: vNetLocation
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetPrefix
      ]
    }
    enableVmProtection: false
    enableDdosProtection: false
    subnets:[for subnet in vnetSubnets: {
      name:subnet.name
      properties:{
        addressPrefix:subnet.prefix
      }
    }]
  }
}

// outputs
@description('resulting vnet id')
output vnetId string = vnet.id
@description('resulting subnet [name,id] list')
output vnetSubnets array = [ for (subnet,i) in vnetSubnets: {
    name: vnet.properties.subnets[i].name
    id: vnet.properties.subnets[i].id
}]

