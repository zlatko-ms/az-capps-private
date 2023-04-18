rgName = rgprivatecapps
location = westeurope
stackName = privatecapps

# fetches resource ids of the demo level provisionned resources, used for resource cleanup
RESIDS = $(shell az resource list --tag ResLocator=MSFT_ACA_PRIVATE_DEMO | jq -r '.[] | select (.resourceGroup=="$(rgName)")| .id' | tr '\n' ' ')
# checks the existence of the resource group, setted to true if the rg exists, false othewise
RGEXISTS= $(shell (az group exists -g $(rgName)) || ( echo "false" ) | (sed 's/\s//g'))
# simple log function
define log-message
@echo "[`date +"%Y%m%d-%H:%M:%S"`] [INFO] $1";
endef

default: deploy

# create the resource group if it does not exist
resource-group:
ifeq ($(RGEXISTS),false)
	$(call log-message,"creating resource group $(rgName) in $(location)")
	@az group create --name $(rgName) --location $(location) --output none
endif

## deploy resources to resource group 
deploy: resource-group
	$(call log-message,"deploying demo resources to resource group $(rgName) in $(location)")
	@az deployment group create --resource-group $(rgName) --template-file src/bicep/main.bicep --parameters stackName=$(stackName) stackLocation=$(location) -o none
	$(call log-message,"demo resources deployed")

## clean the deployed resources based on the tags
clean:
ifneq ($(strip $(RESIDS)),)
	$(call log-message,"cleaning demo resources from resource group $(rgName)")
	@az resource delete --ids $(RESIDS) --verbose
	$(call log-message,"resource cleanup complete")
else
	$(call log-message,"no resources left to clean")
endif
	$(call log-message,"resource group $(rgName) intentionally not removed")