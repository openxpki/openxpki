#!/bin/bash
# Install cpanm
set -euo pipefail

SCRIPTDIR="$(dirname "$0")"
. "$SCRIPTDIR/functions.sh"

if ! command -v cpanm >/dev/null; then
    echo "cpanm"
    curl -s -L https://cpanmin.us | perl - --sudo App::cpanminus >$LOG 2>&1 || _exit $?
else
    echo "cpanm is already installed."
fi
