stackName = privatecapps
rgName = rgprivatecapps
location = westeurope
default: deploy

deploy:
	@az deployment sub create --template-file main.bicep --location $(location) --parameters rgName=$(rgName) stackName=$(stackName) stackLocation=$(location)

clean:
	@az group delete --resource-group $(stackName) --yes
