IMAGE=oxiuibuild
-include Makefile.local

.DEFAULT_GOAL := help

BUILD_UNMINIFIED = 0
DEV_SERVER_FORWARD_TO ?= https://localhost:443
NPM_CUSTOM_REGISTRY ?= http://localhost:4873

#
# Check if "verdaccio" npmjs.org proxy runs on port 4873
#
MANAGER_OPTS_BUILD =
# "shell bash -c ..."" is required to support both:
# systems where "command" is a binary and those where it's a shell builtin
ifneq (, $(shell bash -c 'command -v telnet'))
ifneq (, $(shell echo "close" | telnet localhost 4873 2>/dev/null | grep -i connected))
	MANAGER_OPTS_BUILD = --network host --build-arg NPM_CUSTOM_REGISTRY=$(NPM_CUSTOM_REGISTRY)
endif
endif

ifneq (, $(shell bash -c 'command -v podman'))
	MANAGER = podman
	MANAGER_OPTS_RUN = --network host
#	MANAGER_OPTS = --network slirp4netns:allow_host_loopback=true
else
	MANAGER = docker
	MANAGER_OPTS_RUN = --network host --user `id -u`:`id -g`
#	MANAGER_OPTS = --add-host host.containers.internal:host-gateway
endif

help:
	@grep '^[a-zA-Z]' Makefile | awk -F ':.*?## ' 'NF==2 {printf "  %-26s%s\n", $$1, $$2}'

#
# Compile Ember
#
ember: docker-build compile ## compile Ember code using a Docker image

nocache: MANAGER_OPTS_BUILD += --no-cache
nocache: ember ## compile Ember code in Docker without cache (force re-installation of node_modules)

debug: BUILD_UNMINIFIED = 1 ## compile Ember but with unminified JavaScript + incl. sourcemaps
debug: ember

compile:
	$(MANAGER) run $(MANAGER_OPTS_RUN) -ti --rm \
	  -v $(abspath ./):/source:ro \
	  -v $(abspath ../server/htdocs):/compiled \
	  -e "OPENXPKI_UI_BUILD_UNMINIFIED=$(BUILD_UNMINIFIED)" \
	  $(IMAGE) \
	  build
	perl update-manifest.pl $(abspath ../server)

#
# Run local Ember.js development server
#
serve: docker-build ## run Ember.js development server
	$(MANAGER) run $(MANAGER_OPTS_RUN) -ti --rm \
	  -v $(abspath ./):/source:ro \
	  -e "DEV_SERVER_FORWARD_TO=$(DEV_SERVER_FORWARD_TO)" \
	  $(IMAGE) \
	  serve

#
# Build Docker image
#
# Docker image is built using the internal Docker cache, the last image
# layer holding the copy of the source code is invalidated on code changes
docker-build:
	$(MANAGER) build $(MANAGER_OPTS_BUILD) -f docker/Dockerfile -t $(IMAGE) .

prune: ## remove Docker image
	$(MANAGER) rmi $(IMAGE)
