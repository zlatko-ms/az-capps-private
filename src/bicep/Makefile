stackName = privatecapps
rgName = rgprivatecapps
location = westeurope
# RESIDS = $(shell az resource list --tag Stack=$(stackName) | jq -r '.[] | select (.resourceGroup=="$(rgName)") | .id' | tr '\n' ' ')
RESIDS = $(shell az resource list --tag Stack=$(stackName) | jq -r '.[] | select (.resourceGroup=="$(rgName)")| .id' | tr '\n' ' ')

default: deploy
deploy : deploy-sub
clean : clean-sub

deploy-rg:  
	@echo "[*] deploying to resource group $(rgName) ..."
	@perl -ne 'print unless /\/\/SUBSTART/../\/\/SUBEND/' main.bicep > main.rg.bicep
	@az deployment group create --resource-group $(rgName) --template-file main.rg.bicep --parameters stackName=$(stackName) stackLocation=$(location)
	@rm -f main.rg.bicep

deploy-sub:
	@echo "[*] deploying to subscritption in the resource group $(rgName) ..."
	@az deployment sub create --template-file main.bicep --location $(location) --parameters rgName=$(rgName) stackName=$(stackName) stackLocation=$(location)

clean-sub:
	@echo "[*] deleting resource group $(rgName), this might take a while ..."
	@az group delete --resource-group $(rgName) --yes
	
rg.resource.list:
	@az resource list --tag Stack="$(stackName)" | jq -r '.[] | select (.resourceGroup=="$(rgName)") | .id' | tr '\n' ' ' > rg.resource.list

clean-test: 
	@echo $(RESIDS-TEST)

clean-rg-test:
	@echo "[*] cleaning created resources from resource group $(rgName), this might take a while ..."
	@az resource delete --ids $(RESIDS) --verbose

# clean-rg: rg.resource.list
# 	@echo "[*] cleaning created resources from resource group $(rgName), this might take a while ..."
# 	@$(eval RESIDS=$(shell cat rg.resource.list))
# 	@az resource delete --ids $(RESIDS)
# 	@rm -f rg.resource.list
