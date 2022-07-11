import subprocess

## execute command line and return stdout lines as array
def execCommandGetOutputAsArray(cliCommand):
    result = subprocess.run(cliCommand, stdout=subprocess.PIPE,shell=True)
    output = result.stdout.decode('utf-8').split("\n")
    return output

## checks that the 1st line of the cli exec matches "Succeeded", handy to check provisioningState
def isProvisonnedStateSucceeded(outArray):
    output = outArray[0].strip()
    return output == "Succeeded"

## checks if the container app named appName within the resource group rgName has the provisioningState set to Succeeded
def isContainerAppDeployed(rgName,appName):
    cmd = [ "az containerapp show -n "+appName+" -g "+rgName+" | jq -r '.properties.provisioningState'"]
    resLines = execCommandGetOutputAsArray(cmd)
    return isProvisonnedStateSucceeded(resLines)

## checks if a resource group rgName has been deployed
def isResourceGroupDeployed(rgName):
    cmd = [ "az group show -n "+rgName+" | jq -r '.properties.provisioningState'" ]
    resLines = execCommandGetOutputAsArray(cmd)
    return isProvisonnedStateSucceeded(resLines)


## gets the clientId of a Log analytics workspace named lawName deployed in the resource group rgName
def getLogAnalyticsClientId(rgName,lawName):
    cmd = [ "az deployment group show -g "+rgName+" -n "+lawName+" | jq -r '.properties.outputs.outputLawClientId.value'" ]
    return execCommandGetOutputAsArray(cmd)[0].strip()


## gets the logs of the ca apps named appName , from the Log Analytics client id lawClientId , from now up to the past minutesAgo minutes
def getConsoleLogsForApp(lawClientId,appName,minutesAgo):
    query = "\"ContainerAppConsoleLogs_CL | where ContainerName_s == '"+appName+"' and TimeGenerated > ago("+minutesAgo+"m) | project Log_s\""
    cmd = [ "az monitor log-analytics query -w "+lawClientId+" --analytics-query "+query+" | jq -r '.[].Log_s'"]
    resLines = execCommandGetOutputAsArray(cmd)
    logItems = []
    for i in resLines:
        logItems.append(i.strip("\"").strip())
    return logItems