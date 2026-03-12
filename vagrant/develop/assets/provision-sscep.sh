#!/bin/bash
# Install SQLite client and set up database
set -euo pipefail

SCRIPTDIR="$(dirname "$0")"
. "$SCRIPTDIR/functions.sh"

install_packages libtool automake autoconf pkg-config

git clone --depth 1 https://github.com/certnanny/sscep.git ~/sscep
cd ~/sscep

./bootstrap.sh
./configure
make
make install

rm -rf ~/sscep
