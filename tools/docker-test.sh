#!/bin/bash

# Run unit and QA tests for OpenXPKI in a Docker container.
#
# SYNOPSIS
#   ./docker-test.sh
#       Test latest commit (!) of the current Git branch in your local repo
#
#   ./docker-test.sh myfix
#       Test latest commit of branch "myfix" in your local repo
#
#   ./docker-test.sh develop openxpki/openxpki
#       Test latest commit of branch "develop" in the Github repo "openxpki/openxpki"
#
# DESCRIPTION
#   You need a working Docker installation to run this script.
#   On first execution a Docker image called "oxi-test" is built (might take
#   more than 10 minutes).
#   Then (on every call) a Docker container is created from the image in which
#   the repo is cloned and the tests are executed (takes a few minutes).

branch=$(git rev-parse --abbrev-ref HEAD)
repo=""

test ! -z "$1" && branch="$1"
test ! -z "$2" && repo="$2"

root="$(readlink -e "$(dirname "$0")/../")"

set -e
echo -e "\n====[ Build Docker image ]===="
echo "(This might take more than 10 minutes on first execution)"
docker build $(dirname $0)/docker-test -t oxi-test

echo -e "\n====[ Run tests ]===="
test ! -z "$repo" && echo " - Github repo: $repo" || echo " - local repo"
echo " - branch: $branch"

docker run -t -i --rm -v $root:/repo oxi-test $branch $repo
