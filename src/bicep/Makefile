stackName=acaissue
location=westeurope
default: deploy
reproduce: deploy test

deploy:
	@az deployment sub create --template-file main.bicep --location $(location) --parameters stackName=$(stackName) stackLocation=$(location)

clean:
	@az group delete --resource-group $(stackName) --yes

test:
	@az containerapp logs show -n helloer -g $(stackName)
