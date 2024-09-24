.PHONY: all test

FORK_URL=https://eth-mainnet.g.alchemy.com/v2/OQKqKAM9TwKczODG8t38STEDLBXJTDzp

test :
	@forge test --fork-url $(FORK_URL)

coverage :
	@forge coverage --fork-url $(FORK_URL)

install :; forge install OpenZeppelin/openzeppelin-contracts --no-commit


