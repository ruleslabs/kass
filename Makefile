STARKNET_DIR	= starknet

.PHONY : all clean

all:
	@make --no-print-directory -C $(STARKNET_DIR)

clean: clean-starknet

build-starknet:
	@make build --no-print-directory -C $(STARKNET_DIR)

clean-starknet:
	@make clean --no-print-directory -C $(STARKNET_DIR)
