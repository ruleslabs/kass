.PHONY : all clean

all: clean build

clean: clean-starknet clean-ethereum

build: build-starknet build-ethereum

# STARKNET

build-starknet:
	@echo "\033[1mBuilding Starknet...\033[0m"
	@scarb build
	@echo

clean-starknet:
	@echo "\033[31mCleaning Starknet...\033[0m"
	@scarb clean
	@echo

# ETHEREUM

build-ethereum:
	@echo "\033[1mBuilding Ethereum...\033[0m"
	@forge build
	@echo

clean-ethereum:
	@echo "\033[31mCleaning Ethereum...\033[0m"
	@forge clean
	@echo
