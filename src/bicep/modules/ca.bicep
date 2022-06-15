@description('name of the app')
param caAppName string 
@description('app ingress definition')
param caAppIngress object
@description('app container defitionion')
param caAppContainers array
@description('app environnement id')
param caAppManagedEnvironmentId string
@description('app revision suffix, if any')
param caAppRevisionSuffix string = ''

@description('app min replicas, defaults to 0')
@minValue(0)
@maxValue(30)
param caAppMinReplicas int = 0
@description('app max replicas, defaults to 0')
@minValue(1)
@maxValue(30)
param caAppMaxReplicas int = 10
@description('app tage')
param caAppTags object
@description('app location, default to the rg location')
param caAppEnvLocation string = resourceGroup().location

var tags = union(caAppTags, { 
  Component: 'ContainerApp'
  App: caAppName
 } )


resource capp 'Microsoft.App/containerApps@2022-03-01' = {
  name: caAppName
  location: caAppEnvLocation
  tags: tags
  properties: {
    configuration: {
      activeRevisionsMode: 'single'
      ingress: (empty(caAppIngress) ? null : caAppIngress)
    }
    template: {
      revisionSuffix: caAppRevisionSuffix
      containers: caAppContainers
      scale: {
        minReplicas: caAppMinReplicas
        maxReplicas: caAppMaxReplicas
      }
    }
    managedEnvironmentId: caAppManagedEnvironmentId
  }
}
