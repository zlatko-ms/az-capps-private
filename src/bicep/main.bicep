// 
// DO NOT REMOVE SUBSTART / SUBEND comments from the source code !!!
// Those comments are used to descope from subscription to resource group
//

//SUBSTART
targetScope = 'subscription'
//SUBEND

//SUBSTART
@description('resource group name, will set the destination of the whole stack')
param rgName string = 'rgprivatecapps'
//SUBEND

@description('stack name, will prefix all the ressource deployement names and will be available in all tags')
param stackName string = 'privatecapps'

@description('stack location')
param stackLocation string = 'westeurope'

var keyVaultName = 'kv-${stackName}'

// network infrastructure
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

/** some tags for your ressources*/
var stackTags = {
  Stack: stackName
  Scope: 'DevTest'
  Tech: 'ContainerApps'
  Stream: 'Awareness'
}

var lawSharedKeySecretName = 'lawSharedKey'
//var lawClientIdSecretName  = 'lawClientId'

/** the resource group */
//SUBSTART
resource rg 'Microsoft.Resources/resourceGroups@2021-01-01' = {
  name: rgName
  location: stackLocation
  tags: stackTags
}
//SUBEND

/** vnet infra */
module vnet './modules/vnet.bicep' = {
  name: '${stackName}-vnet'
  //SUBSTART
  scope: resourceGroup(rg.name)
  //SUBEND
  params: {
    vnetName: '${stackName}-vnet'
    vnetPrefix: stackVNetCIDR
    vnetSubnets: stackVNetSubnets
    vNetTags: stackTags
    vNetLocation: stackLocation
  }
}

/** kv for storing deployement secrets */
module kv './modules/kv.bicep' = {
  name: keyVaultName
  //SUBSTART
  scope: resourceGroup(rg.name)
  //SUBEND
  params: {
    kvName: keyVaultName
    kvLocation: stackLocation
    kvTags: stackTags
  }

}

/** log analytics workspace */
module law './modules/law.bicep' = {
  name: '${stackName}-law'
  //SUBSTART
  scope: resourceGroup(rg.name)
  //SUBEND
  params: {
    lawTags: stackTags
    lawLocation: stackLocation
    lawName: '${stackName}-law'
    kvName: keyVaultName
    kvClientSharedKeySecretName: lawSharedKeySecretName
  }
}

/** fetch the kv in order to get the Log Analytics Shared Key */
resource infraSecretsKV 'Microsoft.KeyVault/vaults@2019-09-01' existing = {
  //SUBSTART
  scope: resourceGroup(rg.name)
  //SUBEND
  name: keyVaultName
}

/** ACA env for the backend service */
var caBackendName = 'caenv-backend'
module cabackend './modules/caenv.bicep' = {
  name: '${stackName}-${caBackendName}'
  //SUBSTART
  scope: resourceGroup(rg.name)
  //SUBEND
  params: {
    caEnvLawClientId: law.outputs.outputLawClientId
    caEnvLawSharedKey: infraSecretsKV.getSecret(lawSharedKeySecretName)
    caEnvName: caBackendName
    caEnvLocation: stackLocation
    caEnvPrivate: true
    caEnvZoneRedundant: false
    caEnvTags: stackTags
    caEnvVnetInfraSubnetId: vnet.outputs.vnetSubnets[2].id
  }
}

/** Private DNS zone for the helloer environnement, required to hit the app */
module cabackendns './modules/caenvdns.bicep' = {
  name: '${stackName}-${caBackendName}-dns'
  //SUBSTART
  scope: resourceGroup(rg.name)
  //SUBEND
  params: {
    caEnvName: caBackendName
    caEnvDnsTags: stackTags
    caEnvDnsDomain: cabackend.outputs.caEnvDefaultDomain
    caEnvDnsStaticIp: cabackend.outputs.caEnvStaticIp
    caEnvDnsVnetId: vnet.outputs.vnetId
  }
}

/** ACA env for the greeter (client app illustration) */
var caClientName = 'caenv-client'
module caclient './modules/caenv.bicep' = {
  name: '${stackName}-${caClientName}'
  //SUBSTART
  scope: resourceGroup(rg.name)
  //SUBEND
  params: {
    caEnvLawClientId: law.outputs.outputLawClientId
    caEnvLawSharedKey: infraSecretsKV.getSecret(lawSharedKeySecretName)
    caEnvName: caClientName
    caEnvLocation: stackLocation
    caEnvPrivate: true
    caEnvZoneRedundant: false
    caEnvTags: stackTags
    caEnvVnetInfraSubnetId: vnet.outputs.vnetSubnets[3].id
  }
}

/** Helloer app, will serve the http calls */
var backendAppName = '${stackName}-helloer'
module cahelloer './modules/ca.bicep' = {
  name: '${stackName}-ca-helloer'
  //SUBSTART
  scope: resourceGroup(rg.name)
  //SUBEND
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

/** Greeter client app, will call the backend (helloer) on the follwing url  */
var helloerUrl = 'https://${backendAppName}.${cabackend.outputs.caEnvDefaultDomain}/connectivity/local'
module cagreeter './modules/ca.bicep' = {
  name: '${stackName}-ca-greeter'
  //SUBSTART
  scope: resourceGroup(rg.name)
  //SUBEND
  params: {
    caAppName: '${stackName}-greeter'
    caAppTags: stackTags
    caAppMinReplicas: 1
    caAppMaxReplicas: 1
    caAppEnvLocation: stackLocation
    caAppManagedEnvironmentId: caclient.outputs.caEnvId
    caAppIngress: {}
    caAppContainers: [
      {
        image: 'docker.io/zlatkoa/pgreeter:1.0.2'
        name: '${stackName}-greeter'
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
