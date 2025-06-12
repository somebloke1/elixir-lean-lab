.PHONY: help deps test shell run clean format check

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-15s\033[0m %s\n", $$1, $$2}'

deps: ## Install dependencies
	mix deps.get
	mix deps.compile

test: ## Run tests
	mix test

shell: ## Start interactive Elixir shell
	iex -S mix

run: ## Run the application
	mix run --no-halt

clean: ## Clean build artifacts
	mix clean
	rm -rf _build deps

format: ## Format code
	mix format

check: ## Run all checks (format, compile, tests)
	mix format --check-formatted
	mix compile --warnings-as-errors
	mix test

docs: ## Generate documentation
	mix docs