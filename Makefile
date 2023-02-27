.PHONY : all clean

all: clean build

clean: clean-starknet

build: build-starknet build-ethereum

# STARKNET

build-starknet:
	scarb build

clean-starknet:
	scarb clean

# ETHEREUM

build-ethereum:
	forge build
