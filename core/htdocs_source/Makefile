IMAGE=oxiuibuild
-include Makefile.local

.DEFAULT_GOAL := cache
BUILD_UNMINIFIED = 0

ifneq (, $(shell command -v podman))
	RUN_C = podman
	RUN_C_OPTS =
else
	RUN_C = docker
	RUN_C_OPTS = --user `id -u`:`id -g`
endif

# main target: compile Ember code using (cached) Docker image
cache: build compile

# like "cache" but with unminified JavaScript and incl. sourcemaps
debug: BUILD_UNMINIFIED = 1
debug: cache

# compile Ember code using Docker image (force re-installation of node_modules)
nocache: build-nocache compile

# Docker image is built using the internal Docker cache, the last image
# layer holding the copy of the source code is invalidated on code changes
build:
	$(RUN_C) build -t $(IMAGE) .

# force rebuild, will also update Node.js module dependencies
build-nocache:
	$(RUN_C) build --no-cache -t $(IMAGE) .

compile:
	$(RUN_C) run -ti --rm \
	  -v $(abspath ./):/source:ro \
	  -v $(abspath ../server/htdocs):/compiled \
	  -e "OPENXPKI_UI_BUILD_UNMINIFIED=${BUILD_UNMINIFIED}" \
	  $(RUN_C_OPTS) $(IMAGE)
	perl update-manifest.pl $(abspath ../server)

# remove the build container
prune:
	$(RUN_C) rmi $(IMAGE)
