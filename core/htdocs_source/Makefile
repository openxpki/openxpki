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

#
# Compile Ember
#
ember: docker-build compile ## compile Ember code using a Docker image

nocache: docker-build-nocache compile ## compile Ember code in Docker without cache (force re-installation of node_modules)

debug: BUILD_UNMINIFIED = 1 ## compile Ember but with unminified JavaScript + incl. sourcemaps
debug: ember

compile:
	$(RUN_C) run -ti --rm \
	  -v $(abspath ./):/source:ro \
	  -v $(abspath ../server/htdocs):/compiled \
	  -e "OPENXPKI_UI_BUILD_UNMINIFIED=${BUILD_UNMINIFIED}" \
	  $(RUN_C_OPTS) $(IMAGE) build
	perl update-manifest.pl $(abspath ../server)

#
# Build Docker image
#
# Docker image is built using the internal Docker cache, the last image
# layer holding the copy of the source code is invalidated on code changes
docker-build:
	$(RUN_C) build -f docker/Dockerfile -t $(IMAGE) .

# force rebuild, will also update Node.js module dependencies
docker-build-nocache:
	$(RUN_C) build -f docker/Dockerfile --no-cache -t $(IMAGE) .

prune: ## remove Docker image
	$(RUN_C) rmi $(IMAGE)
