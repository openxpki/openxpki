IMAGE=oxiuibuild
-include Makefile.local

.DEFAULT_GOAL := help
BUILD_UNMINIFIED = 0

ifneq (, $(shell command -v podman))
	RUN_C = podman
	RUN_C_OPTS =
else
	RUN_C = docker
	RUN_C_OPTS = --user `id -u`:`id -g`
endif

help:
	@grep '^[a-zA-Z]' Makefile | awk -F ':.*?## ' 'NF==2 {printf "  %-26s%s\n", $$1, $$2}'

ember: docker-build compile ## compile Ember code in a Docker container

nocache: docker-build-nocache compile ## compile Ember code in Docker without cache (force re-installation of node_modules)

debug: BUILD_UNMINIFIED = 1 ## like "build" but with unminified JavaScript and incl. sourcemaps
debug: ember

prune: ## remove Docker container
	$(RUN_C) rmi $(IMAGE)

# Docker image is built using the internal Docker cache, the last image
# layer holding the copy of the source code is invalidated on code changes
docker-build:
	$(RUN_C) build -t $(IMAGE) .

# force rebuild, will also update Node.js module dependencies
docker-build-nocache:
	$(RUN_C) build --no-cache -t $(IMAGE) .

compile:
	$(RUN_C) run -ti --rm \
	  -v $(abspath ./):/source:ro \
	  -v $(abspath ../server/htdocs):/compiled \
	  -e "OPENXPKI_UI_BUILD_UNMINIFIED=${BUILD_UNMINIFIED}" \
	  $(RUN_C_OPTS) $(IMAGE)
	perl update-manifest.pl $(abspath ../server)
