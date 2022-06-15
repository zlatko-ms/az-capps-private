

@description('name of the ca environnement, for deployement name purposes')
param caEnvName string
@description('vnet for linkning to dns zone')
param caEnvDnsVnetId string
@description('ca environnement dns domain')
param caEnvDnsDomain string
@description('ca environnement static ip')
param caEnvDnsStaticIp string
@description('ca env dns tags')
param caEnvDnsTags object

var specificTags = {
  Component : 'DNS'
}
var tags = union(caEnvDnsTags,specificTags)
var caEnvDnsLocation = 'global'

// the private dns zone
resource caDns 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: caEnvDnsDomain
  location: caEnvDnsLocation
  tags: tags
}

// dns zone vnet registration
resource caDnsVNet 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2018-09-01' = {
  parent: caDns
  name: '${caEnvName}-vnet'
  location: caEnvDnsLocation
  properties: {
    registrationEnabled: true
    virtualNetwork: {
      id: caEnvDnsVnetId
    }
  }
}

// wildecar A record
resource caDnsARecordApps 'Microsoft.Network/privateDnsZones/A@2018-09-01' = {
  parent: caDns
  name: '*'
  properties: {
    ttl: 3600
    aRecords: [
      {
        ipv4Address: caEnvDnsStaticIp
      }
    ]
  }
}



