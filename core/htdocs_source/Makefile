IMAGE=oxiuibuild
-include Makefile.local

.DEFAULT_GOAL := cache

# main target: compile Ember code using (cached) Docker image
cache: build compile

# compile Ember code using Docker image (force re-installation of node_modules)
nocache: build-nocache compile

# Docker image is built using the internal Docker cache, the last image
# layer holding the copy of the source code is invalidated on code changes
build:
	docker build -t $(IMAGE) .

# force rebuild, will also update node deps
build-nocache:
	docker build --no-cache -t $(IMAGE) .

compile:
	[ -L node_modules ] || ln -fs ../node_modules
	docker run -v $(abspath ./):/source:ro -v $(abspath ../server/htdocs):/source/dist -ti $(IMAGE)

# remove the build container
prune:
	docker rmi $(IMAGE)
