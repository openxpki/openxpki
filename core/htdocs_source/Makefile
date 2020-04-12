IMAGE=oxiuibuild
-include Makefile.local

.DEFAULT_GOAL := compile

# Docker image is build using the internal cache, the last cache image
# # holding the copy of the source code is invalidated on code changes
build: 
	docker build -t $(IMAGE) .

# force rebuild, will also update node deps
build-nocache: 
	docker build --no-cache -t $(IMAGE) .

# main target, compile the ember code using the docker image
compile: build
	docker run -v $(abspath ../server/htdocs):/source/dist -ti $(IMAGE) 

# remove the build container
prune:
	docker rmi $(IMAGE)
