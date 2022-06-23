#!/bin/bash
# Install Docker Community Edition

docker_count=$(dpkg -s docker-ce | grep -c "Status:.*installed")
set -e

if [ $docker_count -eq 0 ]; then
  echo "Docker CE"
  KEYRING=/usr/share/keyrings/docker-archive-keyring.gpg

  curl -fsSL https://download.docker.com/linux/debian/gpg \
    | gpg --dearmor -o $KEYRING

  APT_FILE=/etc/apt/sources.list.d/docker.list
  ARCH=$(dpkg --print-architecture)

  echo "deb [arch=$ARCH signed-by=$KEYRING] https://download.docker.com/linux/debian $(lsb_release -cs) stable" | tee $APT_FILE > /dev/null
  apt-get -q=2 update && apt-get -q=2 -o=Dpkg::Use-Pty=0 -y install \
    docker-ce docker-ce-cli containerd.io
else
  echo "Docker CE - already installed."
fi
