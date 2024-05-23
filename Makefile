# Makefile for Foundry Ethereum Development Toolkit

.PHONY: build test format snapshot anvil deploy deploy-anvil cast help subgraph clear-anvil-port

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

forge-snapshot:
	@echo "Creating gas snapshot with Forge..."
	@forge snapshot

anvil-network:
	@echo "Starting Anvil local Ethereum node..."
	@make clear-network-port
	@anvil

hardhat-network:
	@echo "Starting Hardhat local Ethereum node..."
	@make clear-network-port
	@npx hardhat node

forge-deploy-to-local-network:
	@echo "Deploying with Forge to local network..."
	@rm -Rf artifacts/deployments/anvil/
	@mkdir -p artifacts/deployments/anvil/
	@forge create ./contracts/Counter.sol:Counter --rpc-url anvil --unlocked --from 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 | tee artifacts/deployments/anvil/counter.output.txt
	@grep "Deployed to:" ./artifacts/deployments/anvil/counter.output.txt | awk '{print $$3}' | tee artifacts/deployments/anvil/counter.txt

hardhat-deploy-to-local-network:
	@echo "Deploying with Hardhat to local network..."
	@npx hardhat ignition deploy ignition/modules/Counter.ts --network localhost

forge-deploy-to-btp-network:
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
	@rm -Rf artifacts/deployments/btp/
	@mkdir -p artifacts/deployments/btp/
	forge create ./src/Counter.sol:Counter $${EXTRA_ARGS} --rpc-url $${BTP_RPC_URL} $$args --constructor-args "GenericToken" "GT" | tee artifacts/deployments/btp/counter.output.txt;
	@grep "Deployed to:" ./artifacts/deployments/btp/counter.output.txt | awk '{print $$3}' | tee artifacts/deployments/btp/counter.txt

hardhat-deploy-to-btp-network:
	@eval $$(curl -H "x-auth-token: $${BTP_SERVICE_TOKEN}" -s $${BTP_CLUSTER_MANAGER_URL}/ide/foundry/$${BTP_SCS_ID}/env | sed 's/^/export /'); \
	npx hardhat ignition deploy ignition/modules/Counter.ts --network btp

forge-script-to-anvil-network:
	@if [ ! -f deployment-anvil.txt ]; then \
		echo "\033[1;31mERROR: Contract was not deployed or the deployment-anvil.txt went missing.\033[0m"; \
		exit 1; \
	fi
	@DEPLOYED_ADDRESS=$$(grep "Deployed to:" deployment-anvil.txt | awk '{print $$3}') forge script script/Counter.s.sol:CounterScript ${EXTRA_ARGS} --rpc-url anvil -i=1

forge-script-to-btp-network:
	@if [ ! -f deployment.txt ]; then \
		echo "\033[1;31mERROR: Contract was not deployed or the deployment.txt went missing.\033[0m"; \
		exit 1; \
	fi
	@eval $$(curl -H "x-auth-token: $${BTP_SERVICE_TOKEN}" -s $${BTP_CLUSTER_MANAGER_URL}/ide/foundry/$${BTP_SCS_ID}/env | sed 's/^/export /'); \
	if [ -z "${BTP_FROM}" ]; then \
		echo "\033[1;33mWARNING: No keys are activated on the node, falling back to interactive mode...\033[0m"; \
		echo ""; \
		@DEPLOYED_ADDRESS=$$(grep "Deployed to:" deployment.txt | awk '{print $$3}') forge script script/Counter.s.sol:CounterScript ${EXTRA_ARGS} --rpc-url ${BTP_RPC_URL} -i=1; \
	else \
		@DEPLOYED_ADDRESS=$$(grep "Deployed to:" deployment.txt | awk '{print $$3}') forge script script/Counter.s.sol:CounterScript ${EXTRA_ARGS} --rpc-url ${BTP_RPC_URL} --unlocked --froms ${BTP_FROM}; \
	fi

cast:
	@echo "Interacting with EVM via Cast..."
	@cast $(SUBCOMMAND)

help:
	@echo "Forge help..."
	@forge --help
	@echo "Anvil help..."
	@anvil --help
	@echo "Cast help..."
	@cast --help

clear-network-port:
	-fuser -k -n tcp 8545 || exit 0