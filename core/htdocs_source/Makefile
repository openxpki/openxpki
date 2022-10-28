IMAGE=oxiuibuild
-include Makefile.local

.DEFAULT_GOAL := help

BUILD_UNMINIFIED = 0
DEV_SERVER_FORWARD_TO ?= https://localhost:443
NPM_CUSTOM_REGISTRY ?= http://localhost:4873

#
# Helper macros
#

# Strip http:// and https://
strip_proto = $(subst http://,,$(subst https://,,$1))
# Retrieve host of given string
host = $(firstword $(subst :, ,$(call strip_proto,$1)))
# Retrieve port of given string
# If there is no port part in the string, returns the second argument
# (if specified).
# Param:
#   1. String to parse in form 'host[:port]'.
#   2. (optional) Fallback value.
port = $(or $(word 2,$(subst :, ,$(call strip_proto,$1))),$(value 2))

#
# Check if an npmjs.org cache runs on the given port (default: "verdaccio" on 4873)
#
MANAGER_OPTS_BUILD =
MANAGER_OPTS_RUN =
# "shell bash -c ..."" is required to support both:
# systems where "command" is a binary and those where it's a shell builtin
ifneq (, $(shell bash -c 'command -v telnet'))
ifneq (, $(shell echo "close" | telnet $(call host,$(NPM_CUSTOM_REGISTRY)) $(call port,$(NPM_CUSTOM_REGISTRY)) 2>/dev/null | grep -i connected))
	MANAGER_OPTS_BUILD += --network host --build-arg NPM_CUSTOM_REGISTRY=$(NPM_CUSTOM_REGISTRY)
	MANAGER_OPTS_RUN += -e "NPM_CUSTOM_REGISTRY=$(NPM_CUSTOM_REGISTRY)"
endif
endif

ifneq (, $(shell bash -c 'command -v podman'))
	MANAGER = podman
	MANAGER_OPTS_RUN += --network host
#	MANAGER_OPTS = --network slirp4netns:allow_host_loopback=true
else
	MANAGER = docker
	MANAGER_OPTS_RUN += --network host --user `id -u`:`id -g`
#	MANAGER_OPTS = --add-host host.containers.internal:host-gateway
endif

help:
	@grep '^[a-zA-Z]' Makefile | awk -F ':.*?## ' 'NF==2 {printf "  %-26s%s\n", $$1, $$2}'

#
# Compile Ember
#
ember: docker-build ## compile Ember code using a Docker image
	$(MANAGER) run $(MANAGER_OPTS_RUN) -ti --rm \
	  -v $(abspath ./):/source:ro \
	  -v $(abspath ../server/htdocs):/compiled \
	  -e "OPENXPKI_UI_BUILD_UNMINIFIED=$(BUILD_UNMINIFIED)" \
	  $(IMAGE) \
	  build
	perl update-manifest.pl $(abspath ../server)

nocache: MANAGER_OPTS_BUILD += --no-cache
nocache: ember ## compile Ember code in Docker without cache (force re-installation of node_modules)

debug: BUILD_UNMINIFIED = 1 ## compile Ember but with unminified JavaScript + incl. sourcemaps
debug: ember

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
# Update Ember
#
update-ember: docker-build
	$(MANAGER) run $(MANAGER_OPTS_RUN) -ti --rm \
	  -v $(abspath ./):/source:ro \
	  -v $(abspath ./):/output \
	  $(IMAGE) \
	  update-ember

#
# Build Docker image
#
# Docker image is built using the internal Docker cache, the last image
# layer holding the copy of the source code is invalidated on code changes
docker-build:
	$(MANAGER) build $(MANAGER_OPTS_BUILD) -f docker/Dockerfile -t $(IMAGE) .

prune: ## remove Docker image
	$(MANAGER) rmi $(IMAGE)
