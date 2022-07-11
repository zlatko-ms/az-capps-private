stackName=privatecapps
location=westeurope
default: deploy
all: deploy test clean

deploy:
	@cd src/main/infra/bicep; az deployment sub create --template-file main.bicep --location $(location) --parameters stackName=$(stackName) stackLocation=$(location) > deploy

test:
	@cd src/test/infra/behave ; behave

clean:
	@az group delete --resource-group $(stackName) --yes
	rm deploy
