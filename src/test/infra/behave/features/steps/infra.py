import subprocess
from behave import *

def isContainerAppDeployed(rgName,appName):
    cmd = [ "az containerapp show -n "+appName+" -g "+rgName+" | jq -r '.properties.provisioningState'"]
    result = subprocess.run(cmd, stdout=subprocess.PIPE,shell=True)
    output = result.stdout.decode('utf-8').split("\n")[0].strip()
    return output == "Succeeded"

def isResourceGroupDeployed(rgName):
    cmd = [ "az group show -n "+rgName+" | jq -r '.properties.provisioningState'" ]
    result = subprocess.run(cmd, stdout=subprocess.PIPE,shell=True)
    output = result.stdout.decode('utf-8').split("\n")[0].strip()
    return output == "Succeeded"

def getLogAnalyticsClientId(rgName,lawName):
    cmd = [ "az deployment group show -g "+rgName+" -n "+lawName+" | jq -r '.properties.outputs.outputLawClientId.value'" ]
    result = subprocess.run(cmd, stdout=subprocess.PIPE,shell=True)
    output = result.stdout.decode('utf-8').split("\n")[0].strip()
    return output

def getConsoleLogsForApp(lawClientId,appName,minutesAgo):
    query = "\"ContainerAppConsoleLogs_CL | where ContainerName_s == '"+appName+"' and TimeGenerated > ago("+minutesAgo+"m) | project Log_s\""
    cmd = [ "az monitor log-analytics query -w "+lawClientId+" --analytics-query "+query+" | jq -r '.[].Log_s'"]
    result = subprocess.run(cmd, stdout=subprocess.PIPE,shell=True)
    output = result.stdout.decode('utf-8').split("\n")
    logItems = []
    for i in output:
        logItems.append(i.strip("\""))
    return logItems

@given('the "{rgName}" ressource group has been deployed')
def step_impl(context,rgName):
    assert isResourceGroupDeployed(rgName) is True
    context.rgName=rgName

@given('the "{appName}" application has been deployed in that ressource group')
def step_impl(context,appName):
    isContainerAppDeployed(context.rgName,appName)

@given('the Log Analytics workspace named "{lawName}" is deployed')
def step_impl(context,lawName):
    outputLawClientId = getLogAnalyticsClientId(context.rgName,lawName)
    assert len(outputLawClientId) > 0
    context.lawClientId = outputLawClientId

@when('we query the console logs of the "{appName}" application for the last "{minutesAgo}" minutes')
def step_impl(context,appName,minutesAgo):
    consoleLogs = getConsoleLogsForApp(context.lawClientId,appName,minutesAgo)
    assert len(consoleLogs) > 0
    context.consoleLogs = consoleLogs

@then('the queried log contain at least one hit of the "{serviceName}" service')
def step_impl(context,serviceName):
    foundOne = False
    for logItem in context.consoleLogs:
        if logItem.__contains__("sent "+serviceName+" response to client"):
            foundOne = True
            break
    assert foundOne is True

@then('all of the "{serviceName}" hits gathered from the logs shows requests are addressed from the private "{subnetPrefix}" subnet')
def step_impl(context,serviceName,subnetPrefix):
    allOk = True
    for logItem in context.consoleLogs:
        if logItem.__contains__("sent "+serviceName+" response to client"):
            if (not logItem.__contains__("from "+subnetPrefix)):
                allOk = False
                break
    assert allOk is True