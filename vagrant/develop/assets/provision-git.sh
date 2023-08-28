#!/bin/bash
# Install Git client
set -euo pipefail

SCRIPTDIR="$(dirname "$0")"
. "$SCRIPTDIR/functions.sh"

if ! command -v git >/dev/null; then
    echo "Git"
    apt-get install -q=2 -t $(lsb_release -sc)-backports git >$LOG 2>&1
else
    echo "Git - already installed."
fi
