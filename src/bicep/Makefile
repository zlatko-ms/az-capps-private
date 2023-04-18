stackName = privatecapps
rgName = rgprivatecapps
location = westeurope

# Will store the resource Ids that will be deleted based on the tag et resource group name passed as parameters
RESIDS = $(shell az resource list --tag Stack=$(stackName) | jq -r '.[] | select (.resourceGroup=="$(rgName)")| .id' | tr '\n' ' ')
# If resource group doesn't exist, or user lacks read rights on it, the following command will return that the resource group does not exist
# This will trigger below an error at creation time
rgExists= $(shell (az group exists -g $(rgName)) ||( echo "false" ))	

default: deploy
deploy : deploy-sub
clean : clean-sub

deploy-sub:
	@echo "[*] deploying to subscription in an existing or newly created resource group $(rgName) ..."
# Fail fast : If user lacks write rights on the subscription, or read rights on target resource group, the following command will fail and return an error (as expected)
	@if [ $(rgExists) != "true" ]; then az group create --name $(rgName) --location $(location); fi
	@az deployment group create --resource-group $(rgName) --template-file main.bicep --parameters stackName=$(stackName) stackLocation=$(location)

deploy-rg:
	@echo "[*] deploying to the existing resource group $(rgName) ..."
	@az deployment group create --resource-group $(rgName) --template-file main.bicep --parameters stackName=$(stackName) stackLocation=$(location)

clean-sub:
	@echo "[*] deleting resource group $(rgName), this might take a while ..."
	@az group delete --resource-group $(rgName) --yes

clean-rg:
	@echo "[*] cleaning created resources from resource group $(rgName), this might take a while ..."
	@az resource delete --ids $(RESIDS) --verbose