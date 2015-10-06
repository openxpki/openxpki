#!/bin/bash
#
# Install the myperl openxpki debian packages

set -x

dpkg --install /vagrant/myperl/deb/*.deb
/vagrant/setup-dummy.sh


