
help: ## Ask for help!
	@grep -E '^[a-zA-Z0-9_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

build: ## Build docker container for testing
	@bash -l -c 'docker build -t cairo-tests .'

test: ## Run tox tests
	make build && docker run cairo-tests

