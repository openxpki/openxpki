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
MANAGER_OPTS_RUN_VERDACCIO =
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
	MANAGER_OPTS_RUN_VERDACCIO += --user root
#	MANAGER_OPTS = --network slirp4netns:allow_host_loopback=true
else
	MANAGER = docker
	MANAGER_OPTS_BUILD += --build-arg OXI_NODE_MODULES_OWNER=$(shell id -u):$(shell id -g)
	MANAGER_OPTS_RUN += --network host --user $(shell id -u):$(shell id -g)
#	MANAGER_OPTS = --add-host host.containers.internal:host-gateway
endif

.PHONY: help ember nocache debug serve \
		update-ember update-deps update-lockfile \
		docs docker-build prune npm-cache

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
update-ember: DIRTY_FILES = $(shell bash -c "git status --porcelain -uno | grep -v '...config$$' | wc -l")
update-ember: docker-build ## update ember-cli and ember-cli-update
	@if [ "$(DIRTY_FILES)" -ne 0 ]; then echo "\nERROR: this command must be run in a clean Git checkout (i.e. no modified files)\n"; false; fi
	$(MANAGER) run $(MANAGER_OPTS_RUN) -ti --rm \
	  -v $(abspath ./):/source:ro \
	  -v $(abspath ./):/output \
	  $(IMAGE) \
	  update-ember

#
# Update Javascript dependencies
#
update-deps: docker-build ## update all dependencies in package.json
	$(MANAGER) run $(MANAGER_OPTS_RUN) -ti --rm \
	  -v $(abspath ./):/source:ro \
	  -v $(abspath ./):/output \
	  $(IMAGE) \
	  update-deps

#
# Update pnpm-lock.yaml
#
update-lockfile: docker-build ## update pnpm-lock.yaml (after you modified package.json)
	$(MANAGER) run $(MANAGER_OPTS_RUN) -ti --rm \
	  -v $(abspath ./):/source:ro \
	  -v $(abspath ./):/output \
	  $(IMAGE) \
	  update-lockfile

#
# Generate JavaScript documentation
#
docs: docker-build ## create Javascript API documentation in /docs-api
	rm -rf ./docs-api
	mkdir ./docs-api
	$(MANAGER) run $(MANAGER_OPTS_RUN) -ti --rm \
	  -v $(abspath ./):/source:ro \
	  -v $(abspath ./docs-api):/docs-api \
	  $(IMAGE) \
	  docs

#
# Interactive shell
#
shell: docker-build ## run interactive shell
	$(MANAGER) run $(MANAGER_OPTS_RUN) -ti --rm \
	  -v $(abspath ./):/source:ro \
	  --entrypoint /bin/bash \
	  $(IMAGE)

#
# Build Docker image
#
# Docker image is built using the internal Docker cache, the last image
# layer holding the copy of the source code is invalidated on code changes
docker-build:
	$(MANAGER) build $(MANAGER_OPTS_BUILD) -f docker/Dockerfile -t $(IMAGE) .

prune: ## remove Docker image
	$(MANAGER) rmi $(IMAGE)

npm-cache: NPM_CACHE_DIR := $(abspath ./verdaccio-npm-cache)
npm-cache: MOUNT_OPT := $(shell if [ -d $(NPM_CACHE_DIR) ]; then a="y"; else read -r -p "Store cache on host [y/N]? " a; fi; if [ "$$a" = "y" -o "$$a" = "j" ]; then echo "-v \"$(NPM_CACHE_DIR):/verdaccio/storage\""; else echo ""; fi)
npm-cache: ## run local NPM cache "verdaccio" (will be used by containers)
	@if [ -n "$(MOUNT_OPT)" ]; then mkdir -p "$(NPM_CACHE_DIR)"; fi
	$(MANAGER) run $(MANAGER_OPTS_RUN) $(MANAGER_OPTS_RUN_VERDACCIO) -ti --rm \
	  --name verdaccio \
	  -e "VERDACCIO_PORT=$(call port,$(NPM_CUSTOM_REGISTRY))" \
	  $(MOUNT_OPT) \
	  verdaccio/verdaccio

add/%: ## add modules to package.json as devDependencies
	$(MANAGER) run $(MANAGER_OPTS_RUN) -ti --rm \
	  -v $(abspath ./):/source:ro \
	  -v $(abspath ./):/output \
	  $(IMAGE) \
	  add "$*"
