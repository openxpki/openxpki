help:
	@grep '^[a-zA-Z]' $(MAKEFILE_LIST) | awk -F ':.*?## ' 'NF==2 {printf "  %-26s%s\n", $$1, $$2}'

build:  ## rebuild openxpki image using Dockerfile
	docker build -t whiterabbitsecurity/openxpki . 

prune:  ## prune unused images (all!)
	docker image prune -f

init: openxpki-config  ## clone initial config from github
openxpki-config:
	git clone  https://github.com/openxpki/openxpki-config --single-branch --branch=docker

compose: openxpki-config  ## call docker-compose, implies init
	docker-compose up

clean:   ## remove containers but keep volumes
	docker rm docker_openxpki-client_1 docker_openxpki-server_1 docker_db_1

purge:	clean  ## remove containers and volumes
	docker volume rm docker_openxpkidb docker_openxpkilog docker_openxpkisocket

