Feature: Azure Container Apps infrastructure is deployed in private mode
  Scenario: All requests on helloer hello service are addressed through private VNet infrastructure
      Given the "privatecapps" ressource group has been deployed
      And the "helloer" application has been deployed in that ressource group
      And the "greeter" application has been deployed in that ressource group
      And the Log Analytics workspace named "privatecapps-law" is deployed
      When we query the console logs of the "helloer" application for the last "15" minutes
      Then the queried log contain at least one hit of the "hello" service
      And all of the "hello" hits gathered from the logs shows requests are addressed from the private "10.5.64" subnet
