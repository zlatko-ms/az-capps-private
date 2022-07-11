import sys

from behave import *
sys.path.append("..")
from utility import cliwrapper

@given('the "{rgName}" ressource group has been deployed')
def step_impl(context,rgName):
    assert cliwrapper.isResourceGroupDeployed(rgName) is True
    context.rgName=rgName

@given('the "{appName}" application has been deployed in that ressource group')
def step_impl(context,appName):
    cliwrapper.isContainerAppDeployed(context.rgName,appName)

@given('the Log Analytics workspace named "{lawName}" is deployed')
def step_impl(context,lawName):
    outputLawClientId = cliwrapper.getLogAnalyticsClientId(context.rgName,lawName)
    assert len(outputLawClientId) > 0
    context.lawClientId = outputLawClientId

@when('we query the console logs of the "{appName}" application for the last "{minutesAgo}" minutes')
def step_impl(context,appName,minutesAgo):
    consoleLogs = cliwrapper.getConsoleLogsForApp(context.lawClientId,appName,minutesAgo)
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
