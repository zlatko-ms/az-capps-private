stackName=privatecapps
location=westeurope
default: deploy

deploy:
	@az deployment sub create --template-file main.bicep --location $(location) --parameters stackName=$(stackName) stackLocation=$(location)

clean:
	@az group delete --resource-group $(stackName) --yes
