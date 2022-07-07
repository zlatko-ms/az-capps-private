stackName=privatecapps
location=westeurope
default: deploy



deploy:
	@cd src/main/infra/bicep
	@az deployment sub create --template-file main.bicep --location $(location) --parameters stackName=$(stackName) stackLocation=$(location)

test:
	@cd src/test/infra/behave/features
	@behave

clean:
	@az group delete --resource-group $(stackName) --yes
