.PHONY: hardhat-build hardhat-test hardhat-format hardhat-snapshot anvil-network hardhat-network forge-build forge-test forge-format forge-snapshot anvil-network hardhat-network forge-deploy-to-local-network forge-deploy-to-btp-network forge-script-to-anvil-network forge-script-to-btp-network help subgraph clear-anvil-port

CURRENT_TIMESTAMP := $(shell date +%s)
SUBGRAPH_DESCRIPTION := "Solidity Empty"
SUBGRAPH_NAME := "solidity-empty"

hardhat-build:
	@echo "Building with Hardhat..."
	@npx hardhat compile

forge-build:
	@echo "Building with Forge..."
	@forge build

hardhat-test:
	@echo "Testing with Hardhat..."
	@npx hardhat test

forge-test:
	@echo "Testing with Forge..."
	@forge test

forge-format:
	@echo "Formatting with Forge..."
	@forge fmt

anvil-network:
	@echo "Starting Anvil local Ethereum node..."
	@make clear-network-port
	@anvil

hardhat-network:
	@echo "Starting Hardhat local Ethereum node..."
	@make clear-network-port \
		npx hardhat node

forge-deploy-to-local-network:
	@echo "Deploying with Forge to local network..."
	@mkdir -p deployments/
	@forge create ./contracts/Counter.sol:Counter --rpc-url anvil --unlocked --from 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 | tee deployments/forge-deploy-to-local-network.$(CURRENT_TIMESTAMP).txt
	@echo "The address of the deployed contract is stored for your reference in deployments/forge-deploy-to-local-network.$(CURRENT_TIMESTAMP).txt"

hardhat-deploy-to-local-network:
	@echo "Deploying with Hardhat to local network..."
	@mkdir -p deployments/
	@npx hardhat ignition deploy ignition/modules/Counter.ts --network localhost | tee deployments/hardhat-deploy-to-local-network.$(CURRENT_TIMESTAMP).txt
	@echo "The address of the deployed contract is stored for your reference in deployments/hardhat-deploy-to-local-network.$(CURRENT_TIMESTAMP).txt"

forge-deploy-to-btp-network:
	@mkdir -p deployments/
	@eval $$(curl -H "x-auth-token: $${BTP_SERVICE_TOKEN}" -s $${BTP_CLUSTER_MANAGER_URL}/ide/foundry/$${BTP_SCS_ID}/env | sed 's/^/export /'); \
		args=""; \
		if [ ! -z "$${BTP_FROM}" ]; then \
			args="--unlocked --from $${BTP_FROM}"; \
		else \
			echo "\033[1;33mWARNING: No keys are activated on the node, falling back to interactive mode...\033[0m"; \
			echo ""; \
			args="--interactive"; \
		fi; \
		if [ ! -z "$${BTP_GAS_PRICE}" ]; then \
			args="$$args --gas-price $${BTP_GAS_PRICE}"; \
		fi; \
		if [ "$${BTP_EIP_1559_ENABLED}" = "false" ]; then \
			args="$$args --legacy"; \
		fi; \
		forge create ./src/Counter.sol:Counter $${EXTRA_ARGS} --rpc-url $${BTP_RPC_URL} $$args --constructor-args "GenericToken" "GT" | tee deployments/forge-deploy-to-btp-network.$(CURRENT_TIMESTAMP).txt;
	@echo "The address of the deployed contract is stored for your reference in deployments/forge-deploy-to-btp-network.$(CURRENT_TIMESTAMP).txt"

hardhat-deploy-to-btp-network:
	@mkdir -p deployments/
	@eval $$(curl -H "x-auth-token: $${BTP_SERVICE_TOKEN}" -s $${BTP_CLUSTER_MANAGER_URL}/ide/foundry/$${BTP_SCS_ID}/env | sed 's/^/export /'); \
		npx hardhat ignition deploy ignition/modules/Counter.ts --network btp | tee deployments/hardhat-deploy-to-btp-network.$(CURRENT_TIMESTAMP).txt;
	@echo "The address of the deployed contract is stored for your reference in deployments/hardhat-deploy-to-btp-network.$(CURRENT_TIMESTAMP).txt"

subgraph:
	@echo "Deploying the subgraph..."
	@rm -Rf subgraph/subgraph.config.json
	@DEPLOYED_ADDRESS=$$(grep "Deployed to:" deployment.txt | awk '{print $$3}') TRANSACTION_HASH=$$(grep "Transaction hash:" deployment.txt | awk '{print $$3}') BLOCK_NUMBER=$$(cast receipt --rpc-url btp $${TRANSACTION_HASH} | grep "blockNumber" | awk '{print $$2}' | sed '2d') yq e -p=json -o=json '.datasources[0].address = env(DEPLOYED_ADDRESS) | .datasources[0].startBlock = env(BLOCK_NUMBER) | .chain = env(BTP_NODE_UNIQUE_NAME)' subgraph/subgraph.config.template.json > subgraph/subgraph.config.json
	@cd subgraph && npx graph-compiler --config subgraph.config.json --include node_modules/@openzeppelin/subgraphs/src/datasources subgraph/datasources --export-schema --export-subgraph
	@cd subgraph && yq e '.specVersion = "0.0.4"' -i generated/$(SUBGRAPH_NAME).subgraph.yaml
	@cd subgraph && yq e '.description = "$(SUBGRAPH_DESCRIPTION)"' -i generated/$(SUBGRAPH_NAME).subgraph.yaml
	@cd subgraph && yq e '.repository = "https://github.com/settlemint/solidity-token-erc20"' -i generated/$(SUBGRAPH_NAME).subgraph.yaml
	@cd subgraph && yq e '.features = ["nonFatalErrors", "fullTextSearch", "ipfsOnEthereumContracts"]' -i generated/$(SUBGRAPH_NAME).subgraph.yaml
	@cd subgraph && npx graph codegen generated/$(SUBGRAPH_NAME).subgraph.yaml
	@cd subgraph && npx graph build generated/$(SUBGRAPH_NAME).subgraph.yaml
	@eval $$(curl -H "x-auth-token: $${BTP_SERVICE_TOKEN}" -s $${BTP_CLUSTER_MANAGER_URL}/ide/foundry/$${BTP_SCS_ID}/env | sed 's/^/export /'); \
	if [ -z "$${BTP_MIDDLEWARE}" ]; then \
		if [ -z "$${ANVIL_TESTS_PRIVATE_KEY}" ]; then \
			echo "\033[1;31mERROR: You have not launched a graph middleware for this smart contract set, aborting...\033[0m"; \
			exit 1; \
		fi \
	else \
		cd subgraph; \
		npx graph create --node $${BTP_MIDDLEWARE} $${BTP_SCS_NAME}; \
		npx graph deploy --version-label v1.0.$$(date +%s) --node $${BTP_MIDDLEWARE} --ipfs $${BTP_IPFS}/api/v0 $${BTP_SCS_NAME} generated/$(SUBGRAPH_NAME).subgraph.yaml; \
	fi

help:
	@echo "Forge help..."
	@forge --help
	@echo "Anvil help..."
	@anvil --help
	@echo "Cast help..."
	@cast --help

clear-network-port:
	-@fuser -k -n tcp 8545
