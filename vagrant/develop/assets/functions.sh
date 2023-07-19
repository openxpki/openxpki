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
    echo -n "Install packages: "
    to_install=()
    for pkg in "$@"; do
        set +e
        installed=$(/usr/bin/dpkg-query --show --showformat='${db:Status-Status}\n' $pkg 2>&1 | grep -ci ^installed)
        set -e
        if [[ $installed == 0 ]]; then to_install=("${to_install[@]}" $pkg); fi
    done
    if [ "${#to_install[@]}" -gt 0 ]; then
        echo "${to_install[@]}"
        set -e
        # quiet mode -q=2 implies -y
        DEBIAN_FRONTEND=noninteractive apt-get -q=2 install -y "${to_install[@]}" >$LOG 2>&1
        set +e
    else
        echo "required packages already installed ($@)"
    fi
}
