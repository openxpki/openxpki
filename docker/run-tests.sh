#!/bin/bash

# Run unit and QA tests for OpenXPKI.
#
# SYNOPSIS
#   ./run-tests.sh
#       Test latest commit (!) of the current Git branch in your local repo
#
#   ./run-tests.sh myfix
#       Test latest commit of branch "myfix" in your local repo
#
#   ./run-tests.sh develop openxpki/openxpki
#       Test latest commit of branch "develop" in the Github repo "openxpki/openxpki"
#
# DESCRIPTION
#   You need a working Docker installation to run this script.
#   The script will build (only on first execution) and run a Docker container
#   called "oxi-test" that executes the tests.

branch=$(git rev-parse --abbrev-ref HEAD)
repo=""

test ! -z "$1" && branch="$1"
test ! -z "$2" && repo="$2"

root="$(readlink -e "$(dirname $0)/../")"

set -e
echo -e "\n====[ Build Docker image ]===="
docker build $(dirname $0)/test -t oxi-test
echo -e "\n====[ Run tests ]===="
test ! -z "$repo" && echo " - Github repo: $repo" || echo " - local repo"
echo " - branch: $branch"

docker run -t -i --rm -v $root:/repo oxi-test $branch $repo
