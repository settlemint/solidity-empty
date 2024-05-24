.PHONY: hardhat-build hardhat-test hardhat-format hardhat-snapshot anvil-network hardhat-network forge-build forge-test forge-format forge-snapshot anvil-network hardhat-network forge-deploy-to-local-network forge-deploy-to-btp-network forge-script-to-anvil-network forge-script-to-btp-network help subgraph clear-anvil-port

CURRENT_TIMESTAMP := $(shell date +%s)

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

help:
	@echo "Forge help..."
	@forge --help
	@echo "Anvil help..."
	@anvil --help
	@echo "Cast help..."
	@cast --help

clear-network-port:
	-@fuser -k -n tcp 8545
