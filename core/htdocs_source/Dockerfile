FROM node:erbium-buster-slim

RUN apt-get update && \
    apt-get -y install \
        rsync \
        && \
    apt-get clean

RUN mkdir /build && chmod 0777 /build

# Specify command
#   We do some copy magic to ensure we use node_modules/ from the container,
#   not the one bind-mounted one from the host.
#   The output path for compiled assets is changed to /compiled, "outputpath"
#   is used in package.json via "$npm_package_config_outputpath".
RUN echo '#!/bin/bash \n\
set -e \n\
OPTS=(-rlD --delete --inplace --quiet) \n\
rsync "${OPTS[@]}" \\\n\
  --exclude node_modules \\\n\
  --exclude dist \\\n\
  --exclude dist-dev \\\n\
  /source/ /build \n\
rsync "${OPTS[@]}" /node_modules/ /build/node_modules \n\
cd /build \n\
npm config set openxpki:outputpath /compiled \n\
npm run build' > /build.sh \
  && chmod 0755 /build.sh
CMD /build.sh

# Copy depency lists separately to allow for Docker caching
COPY package.json /package.json
COPY package-lock.json /package-lock.json

# install node modules
WORKDIR /
RUN npm install
