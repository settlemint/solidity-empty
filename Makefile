# Makefile for Foundry Ethereum Development Toolkit

.PHONY: build test format snapshot anvil deploy deploy-anvil cast help subgraph

build:
	@echo "Building with Forge..."
	@forge build

test:
	@echo "Testing with Forge..."
	@forge test

format:
	@echo "Formatting with Forge..."
	@forge fmt

snapshot:
	@echo "Creating gas snapshot with Forge..."
	@forge snapshot

anvil:
	@echo "Starting Anvil local Ethereum node..."
	@anvil

deploy-anvil:
	@echo "Deploying with Forge to Anvil..."
	@forge create ./src/Counter.sol:Counter --rpc-url anvil --interactive | tee deployment-anvil.txt

deploy:
	@eval $$(curl -H "x-auth-token: $${BTP_SERVICE_TOKEN}" -s $${BTP_CLUSTER_MANAGER_URL}/ide/foundry/$${BTP_SCS_ID}/env | sed 's/^/export /'); \
	if [ -z "$${BTP_FROM}" ]; then \
		echo "\033[1;33mWARNING: No keys are activated on the node, falling back to interactive mode...\033[0m"; \
		echo ""; \
		if [ -z "$${BTP_GAS_PRICE}" ]; then \
			forge create ./src/Counter.sol:Counter $${EXTRA_ARGS} --rpc-url $${BTP_RPC_URL} --interactive | tee deployment.txt; \
		else \
			forge create ./src/Counter.sol:Counter $${EXTRA_ARGS} --rpc-url $${BTP_RPC_URL} --interactive --gas-price $${BTP_GAS_PRICE} | tee deployment.txt; \
		fi; \
	else \
		if [ -z "$${BTP_GAS_PRICE}" ]; then \
			forge create ./src/Counter.sol:Counter $${EXTRA_ARGS} --rpc-url $${BTP_RPC_URL} --unlocked --from $${BTP_FROM} | tee deployment.txt; \
		else \
			forge create ./src/Counter.sol:Counter $${EXTRA_ARGS} --rpc-url $${BTP_RPC_URL} --unlocked --from $${BTP_FROM} --gas-price $${BTP_GAS_PRICE} | tee deployment.txt; \
		fi; \
	fi

script-anvil:
	@if [ ! -f deployment-anvil.txt ]; then \
		echo "\033[1;31mERROR: Contract was not deployed or the deployment-anvil.txt went missing.\033[0m"; \
		exit 1; \
	fi
	@DEPLOYED_ADDRESS=$$(grep "Deployed to:" deployment-anvil.txt | awk '{print $$3}') forge script script/Counter.s.sol:CounterScript ${EXTRA_ARGS} --rpc-url anvil -i=1

script:
	@if [ ! -f deployment-anvil.txt ]; then \
		echo "\033[1;31mERROR: Contract was not deployed or the deployment-anvil.txt went missing.\033[0m"; \
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
