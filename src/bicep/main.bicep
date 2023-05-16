targetScope = 'resourceGroup'

@description('stack name, will prefix all the ressource deployement names and will be available in all tags')
param stackName string = 'privatecapps'

@description('stack location')
param stackLocation string = 'westeurope'

// process params to overcome some naming constraints 
var lowerStackName = toLower(stackName)

// network infrastructure definition, if required update to fit your CIDR
var stackVNetCIDR = '10.5.0.0/16'
var stackVNetSubnets = [
  {
    name: 'subnet-base'
    prefix: '10.5.0.0/20'
  }
  {
    name: 'subnet-jump'
    prefix: '10.5.16.0/20'
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

// some tags for the deployed ressources, mandatory to locate & clean the provisionned resources 
var stackTags = {
  Stack: stackName
  Scope: 'DevTest'
  Tech: 'ContainerApps'
  Stream: 'Awareness'
  ResLocator: 'MSFT_ACA_PRIVATE_DEMO'
}

// vnet infra 
module vnet './modules/vnet.bicep' = {
  name: '${stackName}-vnet'
  params: {
    vnetName: '${stackName}-vnet'
    vnetPrefix: stackVNetCIDR
    vnetSubnets: stackVNetSubnets
    vNetTags: stackTags
    vNetLocation: stackLocation
  }
}

// log analytics workspace
module law './modules/law.bicep' = {
  name: '${stackName}-law'
  params: {
    lawTags: stackTags
    lawLocation: stackLocation
    lawName: '${stackName}-law'
  }
}

// ACA env for the backend service
var caBackendName = '${stackName}-caenv-backend'
module cabackend './modules/caenv.bicep' = {
  name: caBackendName
  params: {
    caEnvLawName:'${stackName}-law'
    caEnvName: caBackendName
    caEnvLocation: stackLocation
    caEnvPrivate: true
    caEnvZoneRedundant: false
    caEnvTags: stackTags
    caEnvVnetInfraSubnetId: vnet.outputs.vnetSubnets[2].id
  }
}

// Private DNS zone for the helloer environnement, required to hit the app
module cabackendns './modules/caenvdns.bicep' = {
  name: '${stackName}-${caBackendName}-dns'
  params: {
    caEnvName: caBackendName
    caEnvDnsTags: stackTags
    caEnvDnsDomain: cabackend.outputs.caEnvDefaultDomain
    caEnvDnsStaticIp: cabackend.outputs.caEnvStaticIp
    caEnvDnsVnetId: vnet.outputs.vnetId
  }
}

// ACA env for the greeter (client app illustration)
var caClientName = '${lowerStackName}-caenv-client'
module caclient './modules/caenv.bicep' = {
  name: caClientName
  params: {
    caEnvLawName:'${stackName}-law'
    caEnvName: caClientName
    caEnvLocation: stackLocation
    caEnvPrivate: true
    caEnvZoneRedundant: false
    caEnvTags: stackTags
    caEnvVnetInfraSubnetId: vnet.outputs.vnetSubnets[3].id
  }
}

// Helloer app, will serve the http calls
var backendAppName = '${lowerStackName}-helloer'
module cahelloer './modules/ca.bicep' = {
  name: backendAppName
  params: {
    caAppName: backendAppName
    caAppTags: stackTags
    caAppMinReplicas: 1
    caAppMaxReplicas: 1
    caAppEnvLocation: stackLocation
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
            value: backendAppName
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

// Greeter client app, will call the backend (helloer) on the follwing url
var helloerUrl = 'https://${backendAppName}.${cabackend.outputs.caEnvDefaultDomain}/connectivity/local'
module cagreeter './modules/ca.bicep' = {
  name: '${lowerStackName}-ca-greeter'
  params: {
    caAppName: '${lowerStackName}-greeter'
    caAppTags: stackTags
    caAppMinReplicas: 1
    caAppMaxReplicas: 1
    caAppEnvLocation: stackLocation
    caAppManagedEnvironmentId: caclient.outputs.caEnvId
    caAppIngress: {}
    caAppContainers: [
      {
        image: 'docker.io/zlatkoa/pgreeter:1.0.2'
        name: '${lowerStackName}-greeter'
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
