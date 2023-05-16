rgName = rgprivatecappsjuju
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
deploy: deploy-resources
clean: clean-resources clean-log-files
clean-all: clean-resources clean-rg clean-log-files

# create the resource group if it does not exist
resource-group:
ifeq ($(RGEXISTS),false)
	$(call log-message,"creating resource group $(rgName) in $(location)")
	@az group create --name $(rgName) --location $(location) --output none
endif

## deploy resources to resource group 
deploy-resources: resource-group
	$(call log-message,"deploying demo resources to resource group $(rgName) in $(location)")
	@az deployment group create --resource-group $(rgName) --template-file src/bicep/main.bicep --parameters stackName=$(stackName) stackLocation=$(location) -o json 2>&1 | tee -a deploy.log.json
	$(call log-message,"demo resources deployed")

## clean the deployed resources based on the tags
clean-resources:
ifneq ($(strip $(RESIDS)),)
	$(call log-message,"cleaning demo resources from resource group $(rgName)")
	@az resource delete --ids $(RESIDS) --verbose 2>&1 | tee -a clean.log.json
	$(call log-message,"resource cleanup complete")
else
	$(call log-message,"no resources left to clean")
endif
	$(call log-message,"resource group $(rgName) intentionally not removed")

## cleans the rg 
clean-rg:
	$(call log-message,"removing resource group $(rgName)")
	@az group delete --resource-group $(rgName) --yes
	$(call log-message,"resource group removed $(rgName)")

# cleans the temporary log files
clean-log-files:
	@rm -f *.log.json

