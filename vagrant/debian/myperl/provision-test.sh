#!/bin/bash
#
# Provision the myperl test vagrant instance (debian jessie)
# (run as root)

aptitude update

# Install the deps
export DEBIAN_FRONTEND=noninteractive

DEBIAN_FRONTEND=noninteractive apt-get install -y \
    git-core bzip2 screen

# For using openxpki stuff
DEBIAN_FRONTEND=noninteractive apt-get install -y \
    apache2 mysql-server

