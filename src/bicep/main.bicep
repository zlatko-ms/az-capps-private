targetScope = 'subscription'

@description('stack name, will prefix all the ressource deployement names and will be available in all tags')
param stackName string = 'privatecapps'

@description('stack location')
param stackLocation string = 'westeurope'

var stackResourceGroupName  = stackName
var stackVNetCIDR = '10.5.0.0/16'

/** network infrastructure definition */
var stackVNetSubnets = [
  {
    name : 'subnet-base'
    prefix : '10.5.0.0/20'
  }
  {
    name : 'subnet-jump'
    prefix : '10.5.16.0/20'
  }
  {
    name: 'subnet-caenv-infra-backend'
    prefix: '10.5.32.0/20'
  }
  {
     name: 'subnet-caenv-infra-client'
     prefix: '10.5.64.0/20'
  }
]

/** some tags for your ressources*/
var stackTags = {
  Stack: stackName
  Scope: 'DevTest'
  Tech: 'ContainerApps'
  Stream: 'Awareness'
}

/** the resource group */
resource rg 'Microsoft.Resources/resourceGroups@2021-01-01' = {
  name: stackResourceGroupName
  location: stackLocation
  tags: stackTags
}

/** vnet infra */
module vnet './modules/vnet.bicep' = {
  name: '${stackName}-vnet'
  scope: resourceGroup(rg.name)
  params: {    
    vnetName: '${stackName}-vnet'
    vnetPrefix: stackVNetCIDR
    vnetSubnets: stackVNetSubnets
    vNetTags : stackTags
    vNetLocation: rg.location
  } 
}

/** log analytics */
module law './modules/law.bicep' = {
  name: '${stackName}-law'
  scope: resourceGroup(rg.name)
  params: {
   lawTags: stackTags
   lawLocation: rg.location
   lawName: '${stackName}-law'
  }
}

/** container apps env for the backend service*/
var caBackendName = 'caenv-backend'
module cabackend './modules/caenv.bicep' = {
  name: '${stackName}-${caBackendName}'
  scope: resourceGroup(rg.name)
  params: {
    caEnvLawClientId: law.outputs.outputLawClientId
    caEnvLawSharedKey: law.outputs.outputLawClientSecret
    caEnvName: caBackendName
    caEnvLocation: rg.location
    caEnvPrivate: true
    caEnvZoneRedundant: false
    caEnvTags: stackTags
    caEnvVnetInfraSubnetId: vnet.outputs.vnetSubnets[2].id
  }
}

/** private dns zone for the helloer environnement, required to hit the app */
module cabackendns './modules/caenvdns.bicep' = {
  name: '${stackName}-${caBackendName}-dns'
  scope: resourceGroup(rg.name)
  params: {
    caEnvName: caBackendName
    caEnvDnsTags: stackTags
    caEnvDnsDomain: cabackend.outputs.caEnvDefaultDomain
    caEnvDnsStaticIp: cabackend.outputs.caEnvStaticIp
    caEnvDnsVnetId: vnet.outputs.vnetId
  }
}

/** container apps env for the greeter (client app illustration)*/
var caClientName = 'caenv-client'
module caclient './modules/caenv.bicep' = {
  name: '${stackName}-${caClientName}'
  scope: resourceGroup(rg.name)
  params: {
    caEnvLawClientId: law.outputs.outputLawClientId
    caEnvLawSharedKey: law.outputs.outputLawClientSecret
    caEnvName: caClientName
    caEnvLocation: rg.location
    caEnvPrivate: true
    caEnvZoneRedundant: false
    caEnvTags: stackTags
    caEnvVnetInfraSubnetId: vnet.outputs.vnetSubnets[3].id
  }
}

/** the helloer app, will serve the http calls */
var backendAppName = 'helloer'
module cahelloer './modules/ca.bicep' = {
  name: '${stackName}-ca-helloer'
  scope: resourceGroup(rg.name)
  params: {
    caAppName: backendAppName
    caAppTags: stackTags
    caAppMinReplicas: 1
    caAppMaxReplicas: 1
    caAppEnvLocation: rg.location
    caAppManagedEnvironmentId: cabackend.outputs.caEnvId
    caAppIngress: {
      allowInsecure: true
      external: true
      targetPort: 80
      traffic: [
        {
          weight: 100
          latestRevision: true
        }
      ]
    }
    caAppContainers: [
      {
        image: 'docker.io/zlatkoa/helloer:1.0.3'
        name: backendAppName
        resources: {
          cpu: 1
          memory: '2.0Gi'
        }
        env: [
          {
            name: 'HELLOER_PORT'
            value: '80'
          }
          {
            name: 'HELLOER_BACKEND_TYPE'
            value: 'helloer' 
          }

        ]
        probes: [
          {
            type: 'readiness'
            httpGet: {
              scheme: 'http'
              path: '/health'
              port: 80
            }
          }
          {
            type: 'liveness'
            httpGet: {
              path: '/health'
              port: 80
            }
          }
        ]
      }
    ]

  }
}

/** the greeter client app, will call the backend (helloer) on the follwing url  */
var helloerUrl = 'https://${backendAppName}.${cabackend.outputs.caEnvDefaultDomain}/connectivity/local'
module cagreeter './modules/ca.bicep' = {
  name: '${stackName}-ca-greeter'
  scope: resourceGroup(rg.name)
  params: {
    caAppName: 'greeter'
    caAppTags: stackTags
    caAppMinReplicas: 1
    caAppMaxReplicas: 1
    caAppEnvLocation: rg.location
    caAppManagedEnvironmentId: caclient.outputs.caEnvId
    caAppIngress: {} 
    caAppContainers: [
      {
        image: 'docker.io/zlatkoa/pgreeter:1.0.2'
        name: 'greeter'
        resources: {
          cpu: 1
          memory: '2.0Gi'
        }
        env: [
          {
            name: 'GREET_URL'
            value: helloerUrl
          }
          {
            name: 'GREET_SLEEP'
            value: '10' 
          }

        ]
        probes: []
      }
    ]
  }
}
