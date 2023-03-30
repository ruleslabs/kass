-include .env

SOURCE_FILES:=$(shell find src -name "*.cairo")

.PHONY: all
all: fclean build


.PHONY: build
build: ${SOURCE_FILES}
	@echo "\033[1mBuilding Starknet...\033[0m"

	@scarb build

	@echo


.PHONY: test
test:
	@echo "\033[32m\033[1mTesting Starknet...\033[0m"

	@cairo-test . --starknet

	@echo


.PHONY: clean fclean
clean:
	@echo "\033[31m\033[1mCleaning Starknet...\033[0m"

	@scarb clean

	@echo

fclean: clean
