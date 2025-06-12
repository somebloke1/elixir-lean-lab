.PHONY: help build run shell clean size push

IMAGE_NAME := elixir-lean-lab
IMAGE_TAG := latest

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-15s\033[0m %s\n", $$1, $$2}'

build: ## Build the Docker image
	docker build -t $(IMAGE_NAME):$(IMAGE_TAG) .

run: ## Run the container
	docker run -it --rm -p 4000:4000 $(IMAGE_NAME):$(IMAGE_TAG)

shell: ## Start an interactive shell in the container
	docker run -it --rm $(IMAGE_NAME):$(IMAGE_TAG) bin/elixir_lean_lab remote

size: ## Show the image size
	@docker images $(IMAGE_NAME):$(IMAGE_TAG) --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}"

clean: ## Remove the Docker image
	docker rmi $(IMAGE_NAME):$(IMAGE_TAG)

dev: ## Run with docker-compose
	docker-compose up --build

down: ## Stop docker-compose services
	docker-compose down