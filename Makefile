-include .env

.SILENT:
.PHONY : all clean

all: clean build

clean: clean-starknet clean-ethereum

build: build-starknet build-ethereum

test: test-starknet test-ethereum

# STARKNET

build-starknet:
	echo "\033[1mBuilding Starknet...\033[0m"

	mkdir -p target/release

	echo Compiling...
	starknet-compile . target/release/Kass.json --allowed-libfuncs-list-name experimental_v0.1.0
	echo Compiler run successful

	echo

clean-starknet:
	echo "\033[31m\033[1mCleaning Starknet...\033[0m"

	rm -rf target

	echo

test-starknet:
	echo "\033[32m\033[1mTesting Starknet...\033[0m"

	cairo-test --starknet --path .

	echo

# ETHEREUM

build-ethereum:
	echo "\033[1mBuilding Ethereum...\033[0m"

	forge build

	echo

clean-ethereum:
	echo "\033[31m\033[1mCleaning Ethereum...\033[0m"

	forge clean

	echo

test-ethereum:
	echo "\033[32m\033[1mTesting Ethereum...\033[0m"

	forge test

	echo

deploy-ethereum-goerli:
	forge script script/Kass.s.sol:DeployKass \
		--rpc-url ${GOERLI_RPC_URL} \
		--private-key ${PRIVATE_KEY} \
		--broadcast \
		--verify \
		--etherscan-api-key ${ETHERSCAN_API_KEY} \
		-vvvv
