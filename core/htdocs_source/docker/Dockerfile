FROM docker.io/library/node:gallium-buster-slim

# Note: npm needs Git to fetch some modules directly from Github
RUN apt-get update && \
    apt-get -y install \
        rsync \
        git \
        && \
    apt-get clean

RUN mkdir /build && chmod 0777 /build

# Copy depency lists separately to allow for Docker caching
COPY package.json /package.json
COPY package-lock.json /package-lock.json

# install node modules into /node_modules/
WORKDIR /
RUN npm install

# Wrapper script to run "npm run"
COPY docker/npm-run /
ENTRYPOINT [ "/npm-run" ]
