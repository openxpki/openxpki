FROM docker.io/library/node:iron-bookworm-slim

# Note: npm needs Git to fetch some modules directly from Github
RUN apt-get update && \
    apt-get -y install \
        rsync \
        git \
        && \
    apt-get clean

WORKDIR /

RUN mkdir /build && chmod 0777 /build

# accept Github's SSH keys to avoid prompt "Are you sure you want to continue connecting (yes/no)?"
RUN mkdir -p /root/.ssh && ssh-keyscan github.com >> /root/.ssh/known_hosts

# use alternative (local) npm registry if available
ARG NPM_CUSTOM_REGISTRY
RUN test -n "$NPM_CUSTOM_REGISTRY" \
  && echo "==========\nUsing npm registry $NPM_CUSTOM_REGISTRY\n==========" \
  && npm config set registry $NPM_CUSTOM_REGISTRY \
  || echo "\nNo custom npm registry set (or it did not respond)\n"

# update npm and install pnpm
RUN npm install -g npm@9.8.1 \
  && npm install -g pnpm@8.14.1 \
  && pnpm config set auto-install-peers true

# Copy depency lists separately to allow for Docker caching
COPY package.json /
COPY pnpm-lock.yaml /

# install node modules into /node_modules/
RUN pnpm install

# Wrapper script to run "npm run"
COPY docker/pnpm-run /
ENTRYPOINT [ "/pnpm-run" ]
