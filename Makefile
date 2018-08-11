help: ## Show this help
	@fgrep -h "##" $(MAKEFILE_LIST) | \
	fgrep -v fgrep | sed -e 's/## */##/' | column -t -s##

.PHONY: image
image: ## Build a Docker image for raft
image: dist/Dockerfile
	stack install :raft
	docker build --tag bartfrenk/raft \
				 --build-arg executable=raft \
				 ./dist
