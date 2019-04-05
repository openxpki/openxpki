# OpenXPKI@docker

## Using Docker Compose

The provided docker-compose provided creates three containers:

- database (based on mysql:5.7)
- OpenXPKI Server
- OpenXPKI WebUI

Before running compose you **MUST** place a configuration directory named `openxpki-config` in the current directory, the easiest way is to clone the branch `docker` from the `openxpki-config` repository at github.

```bash
$ git clone https://github.com/openxpki/openxpki-config.git --branch=docker
$ docker-compose  up 
```

This will expose the OpenXPKI WebUI via `http://localhost:8080` (**unencrypted**!) with the sample configuration but without any tokens. Place your keys and certificates into the `ca` directory of the config directory and follow the instructions given in the quickstart tutorial: https://openxpki.readthedocs.io/en/latest/quickstart.html#setup-base-certificates.

## Prebuild images

Prebuild images for the official releases are provided by WhiteRabbitSecurity via a public Docker repository `whiterabbitsecurity/openxpki`. 

Those are also used by the docker-compose file.

## Building your own images

The Dockerfile creates a container based on Debian Jessie using prebuild deb packages which are downloaded from the OpenXPKI package mirror (https://packages.openxpki.org).

The image has all code components installed but comes without any configuration. 

The easiest way to start is to clone the `docker` branch from the openxpki-config repository from github `https://github.com/openxpki/openxpki-config` and mount it to `/etc/openxpki`. 

As the container comes without a database engine installed, you must setup a database container yourself and put the connection details into `config.d/system/database.yaml`. 

### WebUI

The container runs only the OpenXPKI daemon but not the WebUI frontend. You can either start apache inside the container or create a second container from the same image that runs the UI. In this case you must create a shared volume for the communication socket mounted at `/var/openxpki/` (this will be changed to (`/run/openxpki/` with one of the next releases!).





