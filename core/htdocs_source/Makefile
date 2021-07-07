IMAGE=oxiuibuild
-include Makefile.local

.DEFAULT_GOAL := cache
BUILD_UNMINIFIED = 0

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
	docker build -t $(IMAGE) .

# force rebuild, will also update Node.js module dependencies
build-nocache:
	docker build --no-cache -t $(IMAGE) .

compile:
	docker run -ti --rm \
	  -v $(abspath ./):/source:ro \
	  -v $(abspath ../server/htdocs):/compiled \
	  -e "OPENXPKI_UI_BUILD_UNMINIFIED=${BUILD_UNMINIFIED}" \
	  --user `id -u`:`id -g` \
	  $(IMAGE)
	perl update-manifest.pl $(abspath ../server)

# remove the build container
prune:
	docker rmi $(IMAGE)
