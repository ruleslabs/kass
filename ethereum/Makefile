-include .env

SOURCE_FILES:=$(shell find src -name "*.sol")

.PHONY: all
all: fclean dependencies build


.PHONY: dependencies forge_dependencies
node_modules: yarn.lock
	rm -rf node_modules
	yarn install --frozen-lockfile

forge_dependencies:
	mkdir -p lib
	forge install foundry-rs/forge-std@v1.4.0 --no-git --no-commit
	forge install openzeppelin/openzeppelin-contracts@v4.8.1 --no-git --no-commit

dependencies: node_modules forge_dependencies


.PHONY: build
build: node_modules ${SOURCE_FILES}
	@echo "\033[1mBuilding Ethereum...\033[0m"

	@forge build

	@echo


.PHONY: test
test:
	@echo "\033[32m\033[1mTesting Ethereum...\033[0m"

	@forge test

	@echo


.PHONY: clean fclean
clean:
	@echo "\033[31m\033[1mCleaning Ethereum...\033[0m"

	rm -rf out

	@echo

fclean: clean
	@echo "\033[31m\033[1mForced Cleaning Ethereum...\033[0m"

	rm -rf node_modules cache lib broadcast

	@echo


.PHONY: goerli-deploy
goerli-deploy:
	forge script script/Kass.s.sol:DeployKass \
		--rpc-url ${GOERLI_RPC_URL} \
		--private-key ${PRIVATE_KEY} \
		--broadcast \
		--verify \
		--etherscan-api-key ${ETHERSCAN_API_KEY} \
		-vvvv
