#!/bin/bash

LOG=$(mktemp)

# Exit handler
function _exit () {
    if [ $1 -ne 0 -a $1 -ne 333 ]; then
        echo "$0: ERROR - last command exited with code $1, output:" >&2 && cat $LOG >&2
    fi
    rm -f $LOG
    exit $1
}

trap '_exit $?' EXIT

# Apt package installations (only ask Apt to install missing packages)
function install_packages {
    to_install=()
    for pkg in "$@"; do
        installed=$(/usr/bin/dpkg-query --show --showformat='${db:Status-Status}\n' $pkg 2>&1 | grep -ci ^installed)
        [ $installed -eq 0 ] && to_install=("${to_install[@]}" $pkg)
    done
    if [ "${#to_install[@]}" -gt 0 ]; then
        echo "Installing packages: ${to_install[@]}"
        set -e
        # quiet mode -q=2 implies -y
        DEBIAN_FRONTEND=noninteractive apt-get -q=2 install "${to_install[@]}" >$LOG 2>&1
        set +e
    else
        echo "All needed OS packages already installed ($@)"
    fi
}
